-- DROP FUNCTION public.gera_relatorio_inadimplencia(int8, text);

CREATE OR REPLACE FUNCTION public.gera_relatorio_inadimplencia(_segcod bigint, _segcaminho text)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
	_header TEXT := '';
    _campos TEXT = '';
    _query TEXT := '';
    _produtoCodigo INT := 0;
    _carteiraCodigo INT := 0;
    _dataInicial DATE := '0001-01-01';
    _dataFinal DATE := '0001-01-01';
    _faseCodigo INT := 0;
    _filtroProduto TEXT := '';
    _filtroCarteira TEXT := '';
    _filtroData TEXT := '';
    _filtroFase TEXT := '';
    _relatorioTipo INT := 0;
BEGIN 
	  
	-- Produto.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _produtoCodigo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 5;
	  
	-- Carteira.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _carteiraCodigo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 48;

	-- Fases de Atraso.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _faseCodigo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 20000;
	  
	-- Período de Referência.
	SELECT COALESCE(s.segfild01, '0001-01-01'), 
		   COALESCE(s.segfild02, '0001-01-01')
	  INTO _dataInicial,
	       _dataFinal
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 20001;

	-- Tipo de Relatório.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _relatorioTipo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 20002;
	  
	IF _produtoCodigo > 0 THEN 
	   _filtroProduto := 'AND ch.procod = '||_produtoCodigo;
	ELSE
	   _filtroProduto := 'AND ch.procod <> 28';
	END IF;

	IF _carteiraCodigo > 0 THEN 
	   _filtroCarteira := 'AND ch.carcod = '||_carteiraCodigo;
	END IF;
 
    IF _dataInicial <> '0001-01-01' AND _dataFinal <> '0001-01-01' THEN 
	   _filtroData := 'SELECT '||_dataInicial|||' data_inicial,
							  '||_dataFinal|||' data_final';
    ELSE 
       IF _relatorioTipo = 0 THEN 
	   _filtroData := 'SELECT date_trunc(''month'', current_date)::date data_inicial,
    	  					 (date_trunc(''month'', current_date) + interval ''1 month - 1 day'')::date data_final';
       ELSE 
   	   _filtroData := 'SELECT date_trunc(''year'', current_date)::date data_inicial,
	  					 (date_trunc(''year'', current_date) + interval ''1 year - 1 day'')::date data_final';
       END IF;
	END IF;

    IF _faseCodigo > 0 THEN 
       _filtroFase := 'AND f.fascod = '||_faseCodigo;
    ELSE 
       _filtroFase := 'AND f.fascod = 5';
    END IF;

	-- Mensal.
    IF _relatorioTipo = 0 THEN 

	    _query := '
			WITH data_referencia AS (
				[FILTRO_DATA]
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
			  	  JOIN data_referencia dr ON ch.cobhisdatinc::date BETWEEN dr.data_inicial AND dr.data_final
			 WHERE ch.conparvalsal > 0 
			   AND ch.conparati = 0
			   [FILTRO_CARTEIRA]
			   [FILTRO_PRODUTO]
			),
			 valor_carteira_periodo AS (
			SELECT sum(cr.conparvalsal) valor_periodo
			  FROM cobranca_registro cr 
			  	  JOIN data_referencia dr ON cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
			 WHERE cr.registro_base = 1 
			   AND (cr.conpardatven < current_date
			       OR EXISTS (SELECT NULL
			       			    FROM credigy_parcela cpp 
			       			    	 JOIN contrato con ON cpp.creparconref = con.concod
			       			   WHERE cpp.creparseq = cr.conparseq
			       			     AND con.connumpar > 1))
			),
			 valor_carteira_total AS (
			SELECT cr.conparvalsal,
				   cr.conparseq,
				   cr.procod
			  FROM cobranca_registro cr 
			 WHERE cr.registro_base = 1 
			   AND (cr.conpardatven < current_date
			       OR EXISTS (SELECT NULL
			       			    FROM credigy_parcela cpp 
			       			    	 JOIN contrato con ON cpp.creparconref = con.concod
			       			   WHERE cpp.creparseq = cr.conparseq
			       			     AND con.connumpar > 1))
			),
			 atraso_medio_periodo AS (
			SELECT sum(current_date - cr.conpardatven) / count(cr.conparseq) atraso_medio
			  FROM cobranca_registro cr 
			 WHERE cr.registro_base = 1 
			   AND (cr.conpardatven < current_date
			       OR EXISTS (SELECT NULL
			       			    FROM credigy_parcela cpp 
			       			    	 JOIN contrato con ON cpp.creparconref = con.concod
			       			   WHERE cpp.creparseq = cr.conparseq
			       			     AND con.connumpar > 1))
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
			 [FILTRO_CARTEIRA]
			),
			 valor_acordo AS (
			SELECT sum(conparvalsal) valor_acordo
			  FROM cobranca_registro_acordo cra
			 WHERE cra.registro_base = 1
			),
			 cobranca_registro_desconto AS (
			SELECT DISTINCT
				   cpc.conparcalval,
				   cpc.conparseq,
				   cpc.tipenccod 
			  FROM cobranca_registro_acordo cra 
			  	  JOIN contrato_parcela cp ON cra.conparseq = cp.conparseq
			  	  JOIN credigy_parcela cpp ON cp.concod = cpp.creparconref
			  	  JOIN contrato_parcela_calculo cpc ON cpp.creparseq = cpc.conparseq AND cpc.conparcalati = 0
			 WHERE cpc.tipenccod >= 6000
			   AND cra.registro_base = 1 
			),
			 valor_desconto AS (
			SELECT sum(crd.conparcalval) valor_desconto
			  FROM cobranca_registro_desconto crd 
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
			),
			 cobranca_registro_retomada AS (
			SELECT DISTINCT 
			       ch.conparseq,
				   cpr.conparretvallan,
				   cpr.tipenccod
			  FROM cobranca_historico ch 
			  	  JOIN contrato_parcela_retomada cpr ON ch.conparseq = cpr.conparseq AND cpr.conparretati = 0 AND cpr.tipenccod < 5000
			  	  JOIN data_referencia dr ON cpr.conparretdatinc::date BETWEEN dr.data_inicial AND dr.data_final
			 WHERE TRUE 
	         [FILTRO_CARTEIRA]
	         [FILTRO_PRODUTO]
			),
			 valor_retomada AS (
			SELECT sum(crr.conparretvallan) valor_retomada
			  FROM cobranca_registro_retomada crr 
			)';
		
		_header := '
		  SELECT ''00 - data ''''mes/ano'''' '',
			     ''01 - atraso medio'',
				 ''02 - (R$) vlr da carteira ''''cadastrada no período'''' '',
				 ''03 - (R$) vlr da carteira ''''acumulada'''' '',
				 ''04 - (R$) vlr cpc'',
				 ''% 04'',
				 ''05 - (R$) vlr cpc negativo'',
				 ''% 05'', 
				 ''06 - vlr acordos'',
				 ''% 06'',
				 ''07 - vlr descontos'',
				 ''% 07'',
				 ''08 - vlr ''''recuperado'''' '',
				 ''% 08''
		   UNION ALL';
		  
		_campos := '
		   SELECT ''[''||to_char(data_inicial, ''MM/YYYY'')||'']'',
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
				   round(((valor_desconto / (valor_acordo + valor_desconto)) * 100), 2)::TEXT,
				   formatar_valor(valor_retomada),
				   round(((valor_retomada / sum(vct.conparvalsal)) * 100), 2)::TEXT::TEXT
			  FROM data_referencia 
			  	  JOIN atraso_medio_periodo ON TRUE 
			      JOIN valor_carteira_periodo ON TRUE 
			  	  JOIN valor_carteira_total vct ON TRUE
			  	  JOIN valor_cpc cpc ON TRUE
			  	  JOIN valor_acordo ON TRUE 
			  	  JOIN valor_desconto ON TRUE 
			  	  JOIN valor_cpc_negativo ON TRUE 
			  	  JOIN valor_retomada ON TRUE 
			 GROUP BY 1, 2, 3, valor_retomada, valor_cpc, valor_acordo, valor_desconto, valor_cpc_negativo';
	 
     ELSE 
     
	    _query := '
			WITH data_referencia AS (
				[FILTRO_DATA]
			),
			 fase_periodo AS (
			SELECT (f.fasdiaini|| '' - ''||f.fasdiafim) faixa,
				   f.fasdiaini dias_inicio,
				   f.fasdiafim dias_fim,
				   f.fasseq sequencia 
			  FROM fases_sequencia f 
			 WHERE TRUE 
               [FILTRO_FASE]
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
	           [FILTRO_CARTEIRA]
		       [FILTRO_PRODUTO]
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
	         [FILTRO_CARTEIRA]
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
	         [FILTRO_CARTEIRA]
	         [FILTRO_PRODUTO]
			),
			 valor_retomada AS (
			SELECT sum(crr.conparretvallan) valor_retomada,
				   crr.faixa
			  FROM cobranca_registro_retomada crr 
			 GROUP BY 2
			)';
     	
     	_header := '
		  (SELECT ''Faixa de atraso'', 
			      ''03 - (R$) vlr da carteira'',
			      ''04 - (R$) vlr cpc'',
			      ''% 04'',
			      ''05 - (R$) vlr cpc negativo'',
			      ''% 05'', 
			      ''06 - vlr acordos'',
			      ''% 06'',
			      ''07 - vlr descontos'',
			      ''% 07'',
			      ''08 - vlr ''''recuperado'''' '',
			      ''% 08'')
		   UNION ALL';
     	
     	_campos := '
	      (SELECT vct.faixa,
		 	      formatar_valor(COALESCE(sum(vct.conparvalsal), 0)),
		   	      formatar_valor(COALESCE(cpc.valor_cpc, 0)),
		          round((COALESCE(cpc.valor_cpc, 0) / COALESCE(sum(vct.conparvalsal), 1) * 100), 2)::TEXT,
		          formatar_valor(COALESCE(vcn.valor_cpc_negativo, 0)),
		          round((COALESCE(vcn.valor_cpc_negativo, 0) / COALESCE(cpc.valor_cpc, 1) * 100), 2)::TEXT,
		          formatar_valor(COALESCE(va.valor_acordo, 0)),
 		          round((COALESCE(va.valor_acordo, 0) / COALESCE(sum(vct.conparvalsal), 1) * 100), 2)::TEXT,
		          formatar_valor(COALESCE(vd.valor_desconto, 0)),
		          round((COALESCE(vd.valor_desconto, 0) / (COALESCE(va.valor_acordo, u8 b 1) + COALESCE(vd.valor_desconto, 1)) * 100), 2)::TEXT,
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
		    ORDER BY sequencia)'; 
     END IF;
    
	 _query := REPLACE(_query, '[FILTRO_PRODUTO]', _filtroProduto);
	 _query := REPLACE(_query, '[FILTRO_CARTEIRA]', _filtroCarteira);
	 _query := REPLACE(_query, '[FILTRO_DATA]', _filtroData);
     _query := _query||_header||_campos;
    
     _query := E'COPY ('||_query||') TO '''||_segcaminho||'''';
    
     RAISE NOTICE '%', _query;
    
     EXECUTE _query;
    
	 INSERT INTO logsegmentacao (logsegcod, logsegque, logsegdatinc, logsegsegcod, logsegbasfil)
     VALUES (DEFAULT, _query, clock_timestamp(), _segcod, 'gera_relatorio_inadimplencia(int8, text)');
    
RETURN '';
EXCEPTION
	WHEN OTHERS THEN
	RAISE EXCEPTION 'Erro%', SQLERRM;
END;
$function$
;
