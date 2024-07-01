CREATE OR REPLACE FUNCTION public.cobranca_historico_atualizacao_saldo(_conparseq bigint)
 RETURNS void
 LANGUAGE sql
AS $function$

WITH contrato_parcela_pagamento AS (
	SELECT COALESCE(cpr.opecod, 0) chave_pagamento,
		   COALESCE(cpr.conparretdatinc, '0001-01-01 00:00:00.000') data_inclusao_pagamento,
		   cp.conparseq 
	  FROM contrato_parcela cp 
	  	  LEFT JOIN contrato_parcela_retomada cpr ON cp.conparseq = cpr.conparseq AND cpr.conparretati = 0 AND cpr.tipenccod = 1
	 WHERE cp.conparseq = _conparseq
	 ORDER BY cpr.conparretdatinc DESC 
	 LIMIT 1
),
  contrato_parcela_devolucao AS (
	SELECT COALESCE(cpm.conparmorseq, 0) chave_devolucao,
		   COALESCE(cpm.conparmordatinc, '0001-01-01 00:00:00.000') data_inclusao_devolucao,
		   cp.conparseq
	  FROM contrato_parcela cp 
	  	  LEFT JOIN contrato_parcela_morto cpm ON cp.conparseq = cpm.conparseq 
	 WHERE cp.conparseq = _conparseq
	 ORDER BY cpm.conparmordatinc DESC 
	 LIMIT 1
),
 contrato_parcela_validacao AS ( 
SELECT CASE 
		   WHEN cpp.data_inclusao_pagamento > cpd.data_inclusao_devolucao AND data_inclusao_pagamento <> '0001-01-01 00:00:00.000' THEN cpp.chave_pagamento
		   WHEN cpd.data_inclusao_devolucao > cpp.data_inclusao_pagamento AND data_inclusao_devolucao <> '0001-01-01 00:00:00.000' THEN cpd.chave_devolucao
		   ELSE 0
		END chave_tabela,
		CASE 
		   WHEN cpp.data_inclusao_pagamento > cpd.data_inclusao_devolucao AND data_inclusao_pagamento <> '0001-01-01 00:00:00.000' THEN 2
		   WHEN cpd.data_inclusao_devolucao > cpp.data_inclusao_pagamento AND data_inclusao_devolucao <> '0001-01-01 00:00:00.000' THEN 3
		   ELSE 7
		END regra_tipo,
		CASE 
		   WHEN cpp.data_inclusao_pagamento > cpd.data_inclusao_devolucao AND data_inclusao_pagamento <> '0001-01-01 00:00:00.000' THEN cpp.conparseq
		   WHEN cpd.data_inclusao_devolucao > cpp.data_inclusao_pagamento AND data_inclusao_devolucao <> '0001-01-01 00:00:00.000' THEN cpd.conparseq
		   ELSE _conparseq
		END conparseq
  FROM contrato_parcela_pagamento cpp
  	 JOIN contrato_parcela_devolucao cpd ON cpp.conparseq = cpd.conparseq
)
INSERT INTO cobranca_historico (conparseq, conparati, conpardatinc, conpardatven, conparvallan, conparvalsal, carcod, procod, cobhismovtip, cobhismovcod)
SELECT cp.conparseq,
       cp.conparati,
       cp.conpardatinc,
       cp.conpardatven,
       cp.conparvallan,
       cp.conparvalsal,
       con.carcod,
       con.procod,
       cpv.regra_tipo,
       cpv.chave_tabela
  FROM contrato con 
  	  JOIN contrato_parcela cp ON con.concod = cp.concod
  	  JOIN contrato_parcela_validacao cpv ON cp.conparseq = cpv.conparseq;
      
$function$
;
