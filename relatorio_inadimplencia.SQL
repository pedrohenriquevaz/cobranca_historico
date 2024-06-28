WITH data_referencia AS (
	SELECT date_trunc('month', current_date)::date data_inicial,
    	  (date_trunc('month', current_date) + interval '1 month - 1 day')::date data_final
),
 cobranca_registro AS (
SELECT ch.conpardatven, 
	   ch.conparseq,
	   ch.conpardatinc,
	   ch.conparvallan,
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
SELECT sum(cr.conparvallan) valor_periodo
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
 WHERE cr.line_number = 1
),
 cobranca_valor_total AS (
SELECT sum(cr.conparvallan) valor_total
  FROM cobranca_registro cr 
      JOIN data_referencia dr ON cr.conpardatinc::date <= data_final
 WHERE cr.line_number = 1
)
SELECT atraso_medio,
	   formatar_valor(valor_periodo) valor_periodo,
	   formatar_valor(valor_total) valor_total
  FROM cobranca_atraso 
  	  JOIN cobranca_valor_cadastrado ON TRUE 
  	  JOIN cobranca_valor_total ON TRUE;
