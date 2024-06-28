CREATE OR REPLACE FUNCTION public.cobranca_historico_criar()
 RETURNS integer
 LANGUAGE sql
AS $function$

WITH inserir_cobranca AS (
	INSERT INTO cobranca_historico (conparseq, conparati, conpardatinc, conpardatven, conparvallan, conparvalsal, carcod, procod)
	SELECT cp.conparseq,
	       cp.conparati,
	       cp.conpardatinc,
	       cp.conpardatven,
	       cp.conparvallan,
	       cp.conparvalsal,
	       con.carcod,
	       con.procod
	  FROM contrato con 
	  	  JOIN contrato_parcela cp ON con.concod = cp.concod
	 WHERE cp.conparvalsal > 0
	   AND cp.conparati <> 1
	RETURNING TRUE
)
SELECT count(*)
  FROM inserir_cobranca;
 
$function$
;
