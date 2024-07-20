WITH data_referencia AS (
	SELECT date_trunc('month', current_date)::date data_inicial,
    	  (date_trunc('month', current_date) + interval '1 month - 1 day')::date data_final
),
 fase_periodo AS (
SELECT (f.fasdiaini|| ' - '||f.fasdiafim) faixa,
	   f.fasdiaini dias_inicio,
	   f.fasdiafim dias_fim,
	   f.fasseq sequencia 
  FROM fases_sequencia f 
 WHERE f.fascod = 5
 ORDER BY f.fasseq
),
 cobranca_registro AS (
SELECT ch.cobhisdatinc::date,
	   ch.conparseq,
	   ch.conparati,
	   ch.conpardatinc,
	   ch.conpardatven,
	   (current_date - ch.conpardatven) dias_ataso,
	   ch.conparvallan,
	   ch.conparvalsal,
	   ch.carcod,
	   ch.procod,
	   ch.cobhismovtip,
	   ch.cobhismovcod,
	   ch.conparacocod,
	   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.conparvalsal DESC, ch.cobhisseq DESC) registro_base
  FROM cobranca_historico ch 
  	  JOIN data_referencia dr ON ch.cobhisdatinc::date BETWEEN dr.data_inicial AND dr.data_final
 WHERE ch.conparvalsal > 0 
   AND ch.conparati = 0
   AND ch.carcod = 1
   AND ch.procod <> 28
),
 valor_carteira_total AS (
SELECT cr.conparvalsal,
	   cr.conparseq,
	   cr.procod,
	   fp.faixa
  FROM cobranca_registro cr 
  	  JOIN fase_periodo fp ON cr.dias_ataso BETWEEN fp.dias_inicio AND fp.dias_fim
 WHERE cr.registro_base = 1 
   AND (cr.conpardatven < current_date
       OR EXISTS (SELECT NULL
       			    FROM credigy_parcela cpp 
       			    	 JOIN contrato con ON cpp.creparconref = con.concod
       			   WHERE cpp.creparseq = cr.conparseq
       			     AND con.connumpar > 1))
),
 valor_cpc AS (
SELECT sum(v.conparvalsal) valor_cpc,
	   v.faixa
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
 GROUP BY 2
),
 cobranca_registro_acordo AS (
SELECT ch.conparvalsal,
	   ch.conparseq,
	   con.devcod,
	   con.carcod,
	   (current_date - ch.conpardatven) dias_atraso,
	   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.conparvalsal DESC, ch.cobhisseq DESC) registro_base
  FROM cobranca_historico ch 
  	  JOIN data_referencia dr ON ch.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
  	  JOIN contrato_parcela cp ON ch.conparseq = cp.conparseq
  	  JOIN contrato con ON cp.concod = con.concod
 WHERE ch.procod = 28
   AND ch.carcod = 1
),
 valor_acordo AS (
SELECT sum(conparvalsal) valor_acordo,
	   fp.faixa
  FROM cobranca_registro_acordo cra
       JOIN fase_periodo fp ON cra.dias_atraso BETWEEN fp.dias_inicio AND fp.dias_fim
 WHERE cra.registro_base = 1
 GROUP BY 2
),
 cobranca_registro_desconto AS (
SELECT DISTINCT
	   cpc.conparcalval,
	   cpc.conparseq,
	   cpc.tipenccod,
	   fp.faixa
  FROM cobranca_registro_acordo cra 
  	  JOIN contrato_parcela cp ON cra.conparseq = cp.conparseq
  	  JOIN credigy_parcela cpp ON cp.concod = cpp.creparconref
  	  JOIN contrato_parcela_calculo cpc ON cpp.creparseq = cpc.conparseq AND cpc.conparcalati = 0
      JOIN fase_periodo fp ON cra.dias_atraso BETWEEN fp.dias_inicio AND fp.dias_fim
 WHERE cpc.tipenccod >= 6000
   AND cra.registro_base = 1 
),
 valor_desconto AS (
SELECT sum(crd.conparcalval) valor_desconto,
	   crd.faixa
  FROM cobranca_registro_desconto crd 
 GROUP BY 2
),
 valor_cpc_negativo AS (
SELECT sum(v.conparvalsal) valor_cpc_negativo,
	   v.faixa
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
 GROUP BY 2
),
 cobranca_registro_retomada AS (
SELECT DISTINCT 
       ch.conparseq,
	   cpr.conparretvallan,
	   cpr.tipenccod,
	   fp.faixa
  FROM cobranca_historico ch 
  	  JOIN contrato_parcela_retomada cpr ON ch.conparseq = cpr.conparseq AND cpr.conparretati = 0 AND cpr.tipenccod < 5000
  	  JOIN data_referencia dr ON cpr.conparretdatinc::date BETWEEN dr.data_inicial AND dr.data_final
  	  JOIN fase_periodo fp ON (current_date - ch.conpardatven) BETWEEN fp.dias_inicio AND fp.dias_fim
 WHERE ch.carcod = 1
),
 valor_retomada AS (
SELECT sum(crr.conparretvallan) valor_retomada,
	   crr.faixa
  FROM cobranca_registro_retomada crr 
 GROUP BY 2
)
(SELECT 'Faixa de atraso', 
	    '03 - (R$) vlr da carteira',
	    '04 - (R$) vlr cpc',
	    '% 04',
	    '05 - (R$) vlr cpc negativo',
	    '% 05', 
	    '06 - vlr acordos',
	    '% 06',
	    '07 - vlr descontos',
	    '% 07',
	    '08 - vlr ''recuperado'' ',
	    '% 08')
 UNION ALL(
SELECT vct.faixa,
	   formatar_valor(COALESCE(sum(vct.conparvalsal), 0)),
   	   formatar_valor(COALESCE(cpc.valor_cpc, 0)),
       round((COALESCE(cpc.valor_cpc, 0) / COALESCE(sum(vct.conparvalsal), 1) * 100), 2)::TEXT,
       formatar_valor(COALESCE(vcn.valor_cpc_negativo, 0)),
       round((COALESCE(vcn.valor_cpc_negativo, 0) / COALESCE(cpc.valor_cpc, 1) * 100), 2)::TEXT,
       formatar_valor(COALESCE(va.valor_acordo, 0)),
       round((COALESCE(va.valor_acordo, 0) / COALESCE(sum(vct.conparvalsal), 1) * 100), 2)::TEXT,
       formatar_valor(COALESCE(vd.valor_desconto, 0)),
       round((COALESCE(vd.valor_desconto, 0) / (COALESCE(va.valor_acordo, 1) + COALESCE(vd.valor_desconto, 1)) * 100), 2)::TEXT,
       formatar_valor(COALESCE(vr.valor_retomada, 0)),
       round((COALESCE(vr.valor_retomada, 0) / COALESCE(sum(vct.conparvalsal), 1) * 100), 2)::TEXT
  FROM fase_periodo fp
  	  LEFT JOIN valor_carteira_total vct ON fp.faixa = vct.faixa
  	  LEFT JOIN valor_cpc cpc ON vct.faixa = cpc.faixa
  	  LEFT JOIN valor_cpc_negativo vcn ON vcn.faixa = vct.faixa
  	  LEFT JOIN valor_acordo va ON va.faixa = vct.faixa
  	  LEFT JOIN valor_desconto vd ON vd.faixa = vct.faixa
  	  LEFT JOIN valor_retomada vr ON vr.faixa = vct.faixa
 GROUP BY 1, 3, sequencia, valor_retomada, valor_cpc, valor_acordo, valor_desconto, valor_cpc_negativo
 ORDER BY sequencia)
