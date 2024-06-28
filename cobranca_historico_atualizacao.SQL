CREATE OR REPLACE FUNCTION public.cobranca_historico_atualizacao(_conparseq bigint, _regratipo integer)
 RETURNS void
 LANGUAGE sql
AS $function$
INSERT INTO cobranca_historico (conparseq, conparati, conpardatinc, conpardatven, conparvallan, conparvalsal, carcod, procod, cobhismovtip)
SELECT cp.conparseq,
       cp.conparati,
       cp.conpardatinc,
       cp.conpardatven,
       cp.conparvallan,
       cp.conparvalsal,
       con.carcod,
       con.procod,
       _regraTipo
  FROM contrato con 
  	  JOIN contrato_parcela cp ON con.concod = cp.concod
 WHERE cp.conparseq = _conparseq;
$function$
;
