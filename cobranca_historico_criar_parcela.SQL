CREATE OR REPLACE FUNCTION public.cobranca_historico_criar_parcela()
 RETURNS void
 LANGUAGE sql
AS $function$
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
   AND NOT EXISTS (SELECT NULL
                     FROM cobranca_historico ch
                    WHERE ch.conparseq = cp.conparseq);
$function$
;
