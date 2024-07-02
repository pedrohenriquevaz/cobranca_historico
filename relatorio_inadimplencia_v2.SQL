WITH data_referencia AS (
	SELECT date_trunc('month', current_date)::date data_inicial,
    	  (date_trunc('month', current_date) + interval '1 month - 1 day')::date data_final
),
 cobranca_registro AS (
SELECT ch.conpardatven, 
	   ch.conparseq,
	   ch.conpardatinc,
	   ch.conparvallan,
	   ch.conparvalsal,
	   ch.procod,
	   ch.carcod,
	   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.cobhisseq DESC) line_number
  FROM cobranca_historico ch 
  	  JOIN data_referencia dr ON ch.cobhisdatinc::date BETWEEN dr.data_inicial AND dr.data_final
 WHERE ch.conparvalsal > 0 
   AND ch.conparati = 0
   AND ch.conpardatven < current_date
),
 cobranca_atraso AS (
SELECT sum(current_date - cr.conpardatven) / count(cr.conparseq) atraso_medio
  FROM cobranca_registro cr 
 WHERE cr.line_number = 1
),
  cobranca_valor_cadastrado AS (
SELECT sum(cr.conparvalsal) valor_periodo
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
 WHERE cr.line_number = 1
),
 cobranca_valor_total AS (
SELECT sum(cr.conparvalsal) valor_total_acumulado
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date <= data_final
 WHERE cr.line_number = 1
),
 cobranca_valor_positivo AS (
SELECT sum(cr.conparvallan) valor_total_cpc
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date <= data_final
      JOIN contrato_parcela cp ON cr.conparseq = cp.conparseq
      JOIN contrato con ON cp.concod = con.concod AND cr.carcod = con.carcod
 WHERE cr.line_number = 1
   AND EXISTS (SELECT NULL
                 FROM retorno ret 
                 	  JOIN carteira_situacao cs ON ret.carcod = cs.carcod AND ret.sitcod = cs.sitcod
                WHERE ret.devcod = con.devcod 
                  AND ret.carcod = con.carcod 
                  AND ret.retdataca BETWEEN data_inicial AND data_final
                  AND cs.tipconcod = 1
                LIMIT 1)
),
 cobranca_valor_acordo AS (
SELECT sum(cr.conparvallan) valor_acordo
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date <= data_final
 WHERE cr.line_number = 1
   AND cr.procod = 28
   AND cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
)
SELECT atraso_medio,
	   formatar_valor(COALESCE(valor_periodo, 0)) valor_periodo,
	   formatar_valor(valor_total_acumulado) valor_total_acumulado,
	   formatar_valor(valor_total_cpc) valor_total_cpc,
	   '',
	   '',
	   '',
	   formatar_valor(COALESCE(valor_acordo, 0))
  FROM cobranca_atraso 
  	  JOIN cobranca_valor_cadastrado ON TRUE 
  	  JOIN cobranca_valor_total ON TRUE
  	  JOIN cobranca_valor_positivo ON TRUE 
  	  JOIN cobranca_valor_acordo ON TRUE
