--EXPLAIN (ANALYZE, costs, buffers, FORMAT JSON)
WITH data_referencia AS (
	SELECT date_trunc('month', current_date)::date data_inicial,
    	  (date_trunc('month', current_date) + interval '1 month - 1 day')::date data_final
),
 cobranca_registro AS (
SELECT ch.cobhisdatinc::date,
	   ch.conparseq,
	   ch.conparati,
	   ch.conpardatinc,
	   ch.conpardatven,
	   ch.conparvallan,
	   ch.conparvalsal,
	   ch.carcod,
	   ch.procod,
	   ch.cobhismovtip,
	   ch.cobhismovcod,
	   ch.conparacocod,
	   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.conparvalsal DESC, ch.cobhisseq DESC) registro_base
  FROM cobranca_historico ch 
--  	   JOIN data_referencia dr ON ch.cobhisdatinc BETWEEN dr.data_inicial AND dr.data_final
 WHERE ch.conparvalsal > 0 
   AND ch.conparati = 0
   AND ch.carcod = 1
   AND ch.procod <> 28 -- desconsidera acordo NO valor de carteira
),
 valor_carteira_periodo AS (
SELECT sum(cr.conparvalsal) valor_periodo
  FROM cobranca_registro cr 
  	  JOIN data_referencia dr ON cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
 WHERE cr.registro_base = 1 
   AND cr.conpardatven < current_date
),
 valor_carteira_total AS (
SELECT cr.conparvalsal,
	   cr.conparseq,
	   cr.procod
  FROM cobranca_registro cr 
 WHERE cr.registro_base = 1 
   AND cr.conpardatven < current_date
),
 atraso_medio_periodo AS (
SELECT sum(current_date - cr.conpardatven) / count(cr.conparseq) atraso_medio
  FROM cobranca_registro cr 
 WHERE cr.registro_base = 1 
   AND cr.conpardatven < current_date
),
 valor_cpc AS (
SELECT sum(v.conparvalsal) valor_cpc
  FROM valor_carteira_total v
	  JOIN contrato_parcela cp ON v.conparseq = cp.conparseq
	  JOIN contrato con ON cp.concod = con.concod
 WHERE EXISTS (SELECT NULL
 			 	 FROM retorno ret
 			 	 	  JOIN carteira_situacao cs ON ret.sitcod = cs.sitcod AND ret.carcod = cs.carcod AND cs.tipconcod = 1
 			 	 	  JOIN data_referencia dr ON ret.retdatinc::date BETWEEN dr.data_inicial AND dr.data_final
 			 	WHERE ret.devcod = con.devcod 
 			 	  AND ret.carcod = con.carcod
 			 	LIMIT 1)
),
 cobranca_registro_acordo AS (
SELECT ch.conparvalsal,
	   ch.conparseq,
	   con.devcod,
	   con.carcod,
	   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.conparvalsal DESC, ch.cobhisseq DESC) registro_base
  FROM cobranca_historico ch 
  	  JOIN data_referencia dr ON ch.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
  	  JOIN contrato_parcela cp ON ch.conparseq = cp.conparseq
  	  JOIN contrato con ON cp.concod = con.concod
 WHERE ch.procod = 28
   AND EXISTS (SELECT NULL
   				 FROM contrato_parcela cp 
   				WHERE cp.conparseq = ch.conparseq)
),
 valor_acordo AS (
SELECT sum(conparvalsal) valor_acordo
  FROM cobranca_registro_acordo cra
 WHERE cra.registro_base = 1
),
 valor_desconto AS (
SELECT sum(cpc.conparcalval) valor_desconto
  FROM cobranca_registro_acordo cra 
  	  JOIN contrato_parcela cp ON cra.conparseq = cp.conparseq
  	  JOIN credigy_parcela cpp ON cp.concod = cpp.creparconref
  	  JOIN contrato_parcela_calculo cpc ON cpp.creparseq = cpc.conparseq
 WHERE cpc.tipenccod > 6000
),
 valor_cpc_negativo AS (
SELECT sum(v.conparvalsal) valor_cpc_negativo
  FROM valor_carteira_total v
	  JOIN contrato_parcela cp ON v.conparseq = cp.conparseq
	  JOIN contrato con ON cp.concod = con.concod
 WHERE EXISTS (SELECT NULL
 			 	 FROM retorno ret
 			 	 	  JOIN carteira_situacao cs ON ret.sitcod = cs.sitcod AND ret.carcod = cs.carcod AND cs.tipconcod = 1
 			 	 	  JOIN data_referencia dr ON ret.retdatinc::date BETWEEN dr.data_inicial AND dr.data_final
 			 	WHERE ret.devcod = con.devcod 
 			 	  AND ret.carcod = con.carcod
 			 	LIMIT 1)
 	AND NOT EXISTS (SELECT NULL 
 					  FROM cobranca_registro_acordo cra
 					 WHERE cra.devcod = con.devcod
 					   AND cra.carcod = con.carcod)
)
SELECT '00 - data ''mes/ano'' ',
	   '01 - atraso medio',
	   '02 - (R$) vlr da carteira ''cadastrada no período'' ',
	   '03 - (R$) vlr da carteira ''acumulada'' ',
	   '04 - (R$) vlr cpc',
	   '% 04',
	   '05 - (R$) vlr cpc negativo',
	   '% 05',
	   '06 - vlr acordos',
	   '% 06',
	   '07 - vlr descontos',
	   '% 07'
 UNION ALL 
SELECT '['||to_char(data_inicial, 'MM/YYYY')||']',
	   atraso_medio::TEXT,
	   formatar_valor(valor_periodo),
	   formatar_valor(sum(vct.conparvalsal)),
	   formatar_valor(valor_cpc),
	   round(((valor_cpc / sum(vct.conparvalsal)) * 100), 2)::TEXT,
	   formatar_valor(valor_cpc_negativo),
	   round((valor_cpc_negativo / valor_cpc) * 100, 2)::TEXT,
	   formatar_valor(valor_acordo),
	   round(((valor_acordo / sum(vct.conparvalsal)) * 100), 2)::TEXT,
	   formatar_valor(valor_desconto),
	   round(((valor_desconto / (valor_acordo + valor_desconto)) * 100), 2)::TEXT
  FROM data_referencia 
  	  JOIN atraso_medio_periodo ON TRUE 
      JOIN valor_carteira_periodo ON TRUE 
  	  JOIN valor_carteira_total vct ON TRUE
  	  JOIN valor_cpc cpc ON TRUE
  	  JOIN valor_acordo ON TRUE 
  	  JOIN valor_desconto ON TRUE 
  	  JOIN valor_cpc_negativo ON TRUE 
 GROUP BY 1, 2, 3, 7, 9, 11, valor_cpc, valor_acordo, valor_desconto, valor_cpc_negativo
   	
 
