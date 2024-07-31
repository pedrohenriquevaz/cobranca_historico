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
    _relatorioTipo INT := 0;
    _visaoRelatorio INT := 0;   
    _dataCalculo TEXT := '0001-01-01';
    _regraVencimento INT := 0;
    _diasAtraso INT := 1;
    _clienteAjuizado TEXT := '';
    _filtroProduto TEXT := '';
    _filtroProdutoRetomada TEXT := '';
    _filtroCarteira TEXT := '';
    _filtroPeriodo TEXT := '';
    _filtroFase TEXT := '';
    _filtroVisaoRelatorio TEXT := '';
    _filtroDataAtraso TEXT := '';
    _filtroAjuizado TEXT := '';
    _filtroRegraVencimento TEXT := '';
    _filtroDataCalculo TEXT := '';
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

	-- Tipo de Relatório.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _relatorioTipo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 600;
	  
	-- Período de Referência.
	SELECT COALESCE(s.segfild01, '0001-01-01'), 
		   COALESCE(s.segfild02, '0001-01-01')
	  INTO _dataInicial,
	       _dataFinal
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 601;

	-- Fases de Atraso.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _faseCodigo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 602;
	
	-- Visão do Relatório
	SELECT COALESCE(s.segfili01, 0)
	  INTO _visaoRelatorio
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 603;
	  
	-- Dias para considerar atraso.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _diasAtraso 
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 604;  
	  
	-- Clientes Ajuizados.
	SELECT COALESCE(s.segfilc01, 'S')
	  INTO _clienteAjuizado
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 605;
	  
	-- Regra de Faturas a Considerar.
	SELECT COALESCE(s.segfili01, 0)
	  INTO _regraVencimento
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 606;  
	  
    -- Data de Cálculo.
	SELECT COALESCE(''''||s.segfild01||'''', '0001-01-01')
	  INTO _dataCalculo
	  FROM segmentacaolevel1level2 s
	 WHERE s.segcod = _segcod
	   AND s.segfilcod = 607; 
	
	IF _dataCalculo ISNULL THEN 
	   _dataCalculo := '0001-01-01';
	END IF;
	  
	-- Produto.
	IF _produtoCodigo > 0 THEN 
	   _filtroProduto := 'AND ch.procod = '||_produtoCodigo;
	   _filtroProdutoRetomada := 'AND ch.procod = '||_produtoCodigo;
	ELSE
	   _filtroProduto := 'AND ch.procod <> 28';
	END IF;

	-- Carteira.
	IF _carteiraCodigo > 0 THEN 
	   _filtroCarteira := 'AND ch.carcod = '||_carteiraCodigo;
	END IF;
 
    -- Período de Referência.
    IF _dataInicial <> '0001-01-01' AND _dataFinal <> '0001-01-01' THEN 
	   _filtroPeriodo := 'SELECT '''||_dataInicial||'''::DATE data_inicial,
							  '''||_dataFinal||'''::DATE data_final';
    ELSE 
       IF _relatorioTipo = 0 THEN 
	   _filtroPeriodo := 'SELECT date_trunc(''month'', current_date)::date data_inicial,
    	  					 (date_trunc(''month'', current_date) + interval ''1 month - 1 day'')::date data_final';
       ELSE 
   	   _filtroPeriodo := 'SELECT date_trunc(''year'', current_date)::date data_inicial,
	  					 (date_trunc(''year'', current_date) + interval ''1 year - 1 day'')::date data_final';
       END IF;
	END IF;

	-- Fases de Atraso.
    IF _faseCodigo > 0 THEN 
       _filtroFase := 'AND f.fascod = '||_faseCodigo;
    ELSE 
       _filtroFase := 'AND f.fascod = 6';
    END IF;
   
    -- Data de Cálculo do atraso.
    IF _dataCalculo <> '0001-01-01' THEN 
       _filtroDataCalculo := _dataCalculo;
    ELSE
       _filtroDataCalculo := ''''||to_char(current_date, 'YYYY-MM-DD')||'''';
       _dataCalculo := ''''||to_char(current_date, 'YYYY-MM-DD')||''''; -- Preencher a própria variável é sacanagem.
    END IF;
   
    -- Dias para considerar atraso.
    IF _diasAtraso <> 0 THEN
       _diasAtraso := _diasAtraso - 1;
       _filtroDataAtraso := ''''||to_char(REPLACE(_dataCalculo, '''', '')::DATE - _diasAtraso, 'YYYY-MM-DD')||'''';
    ELSE 
       _filtroDataAtraso := _dataCalculo;
    END IF;
   
    -- Clientes Ajuizados.
    IF _clienteAjuizado = 'N' THEN 
	   _filtroAjuizado := '
		   AND NOT EXISTS (SELECT NULL 
							 FROM contrato con 
								 JOIN contrato_parcela cp ON con.concod = cp.concod
							 WHERE ch.conparseq = cp.conparseq
							   AND COALESCE(devedor_ultima_situacao(con.devcod, con.carcod), ''NAO INFORMADO'') = ''AJUIZADO'')';
	END IF;

    -- Regra de Faturas a Considerar.
    IF _regraVencimento = 0 THEN
      _filtroRegraVencimento := '
			AND (cr.conpardatven < [FILTRO_DATA_ATRASO]
	         OR EXISTS (SELECT NULL
	        			  FROM credigy_parcela cpp 
	       			    	 JOIN contrato con ON cpp.creparconref = con.concod
 	       			     WHERE cpp.creparseq = cr.conparseq
	       			       AND con.connumpar > 1))';
    ELSE 
      _filtroRegraVencimento := '
		AND EXISTS (SELECT NULL 
					  FROM devedor dev 
	                      JOIN contrato con ON dev.devcod = con.devcod AND dev.carcod = con.carcod
					      JOIN contrato_parcela cp ON cr.conparseq = cp.conparseq
					 WHERE dev.devvenmaisantigo < [FILTRO_DATA_ATRASO])';
    END IF;
    
    
	-- Mensal.
    IF _relatorioTipo = 0 THEN 
		    
           -- Visão Credor.
           IF _visaoRelatorio = 0 THEN 
		       _filtroVisaoRelatorio := '
					SELECT DISTINCT 
						   cppp.conparvallan,
						   cppp.conparseq,
						   con.devcod,
						   con.carcod,
						   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.cobhisseq DESC) registro_base
					  FROM cobranca_historico ch 
					  	  JOIN data_referencia dr ON ch.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
					  	  JOIN contrato_parcela cp ON ch.conparseq = cp.conparseq
					  	  JOIN contrato con ON cp.concod = con.concod
					  	  JOIN credigy_parcela cpp ON con.concod = cpp.creparconref
					  	  JOIN contrato_parcela cppp ON cpp.creparseq = cppp.conparseq -- Parcelas Originais.
					 WHERE ch.procod = 28
					 [FILTRO_CARTEIRA]
					),
					 valor_acordo AS (
					SELECT sum(conparvallan) valor_acordo
					  FROM cobranca_registro_acordo cra
					 WHERE cra.registro_base = 1
					),
					 cobranca_registro_desconto AS (
					SELECT DISTINCT
						   cpc.conparcalval,
						   cpc.conparseq,
						   cpc.tipenccod
					  FROM cobranca_registro_acordo cra 
					  	  JOIN contrato_parcela_calculo cpc ON cra.conparseq = cpc.conparseq AND cpc.conparcalati = 0
					 WHERE cpc.tipenccod >= 6000
					   AND cra.registro_base = 1';
	        ELSE 
	        -- Visão Assessoria.
		       _filtroVisaoRelatorio := '
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
					   AND cra.registro_base = 1 ';
	        END IF;
    
	    _query := '
			WITH data_referencia AS (
				[FILTRO_DATA]
			),
			 cobranca_ultimo_registro AS (
			SELECT ch.cobhisdatinc::date,
				   ch.conparseq,
				   ch.conparati,
				   ch.conpardatinc,
				   CASE WHEN trim(cpd.conpardetcar) = ''SIM'' THEN ch.conpardatven - 360 ELSE ch.conpardatven END, -- Parcela de prejuízo adiciona 360 dias ao atraso.
				   ch.conparvallan,
				   ch.conparvalsal,
				   ch.carcod,
				   ch.procod,
				   ch.cobhismovtip,
				   ch.cobhismovcod,
				   ch.conparacocod,
				   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.cobhisseq DESC) registro_base
			  FROM cobranca_historico ch 
			  	  JOIN data_referencia dr ON ch.cobhisdatinc::date BETWEEN dr.data_inicial AND dr.data_final
				  LEFT JOIN contrato_parcela_detalhe cpd ON cpd.conparseq = ch.conparseq AND cpd.conpardetcod = 30 -- Parcela de prejuízo adiciona 360 dias ao atraso.
			 WHERE TRUE 
			   [FILTRO_CARTEIRA]
			   [FILTRO_PRODUTO]
			   [FILTRO_AJUIZADO]
			),
			 cobranca_registro AS (
			SELECT *
			  FROM cobranca_ultimo_registro c
			 WHERE c.registro_base = 1 
			   AND c.conparvalsal > 0
			   AND c.conparati = 0
			),
			 valor_carteira_periodo AS (
			SELECT sum(cr.conparvalsal) valor_periodo
			  FROM cobranca_registro cr 
			  	  JOIN data_referencia dr ON cr.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
			 WHERE TRUE /*cr.registro_base = 1*/
			   [FILTRO_REGRA_VENCIMENTO]
			),
			 valor_carteira_total AS (
			SELECT cr.conparvalsal,
				   cr.conparseq,
				   cr.procod
			  FROM cobranca_registro cr 
			 WHERE TRUE /*cr.registro_base = 1*/
			   [FILTRO_REGRA_VENCIMENTO]
			),
			 atraso_medio_periodo AS (
			SELECT sum([FILTRO_DATA_CALCULO] - cr.conpardatven) / count(cr.conparseq) atraso_medio
			  FROM cobranca_registro cr 
			 WHERE TRUE /* cr.registro_base = 1 */
			   [FILTRO_REGRA_VENCIMENTO]
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
		     [FILTRO_VISAO_RELATORIO]
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
			SELECT cpr.conparretvallan,
				   cpr.tipenccod
			  FROM cobranca_historico ch 
			  	  JOIN contrato_parcela_retomada cpr ON ch.conparseq = cpr.conparseq AND cpr.conparretati = 0 
			  	  JOIN data_referencia dr ON cpr.conparretdatinc::date BETWEEN dr.data_inicial AND dr.data_final
	         [FILTRO_CARTEIRA]
	         [FILTRO_PRODUTO_RETOMADA]
			),
			 valor_retomada AS (
			SELECT (sum(crr.conparretvallan) FILTER (WHERE crr.tipenccod <= 5000)) - COALESCE((sum(crr.conparretvallan) FILTER (WHERE crr.tipenccod >= 6001)), 0) valor_retomada
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
                   -- Visão Credor.
           IF _visaoRelatorio = 0 THEN 
		       _filtroVisaoRelatorio := '
					SELECT DISTINCT 
						   cppp.conparvallan,
						   cppp.conparseq,
						   con.devcod,
						   con.carcod,
						   (con.condatinc::date - cppp.conpardatven) dias_atraso,
						   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.cobhisseq DESC) registro_base
					  FROM cobranca_historico ch 
					  	  JOIN data_referencia dr ON ch.conpardatinc::date BETWEEN dr.data_inicial AND dr.data_final
					  	  JOIN contrato_parcela cp ON ch.conparseq = cp.conparseq
					  	  JOIN contrato con ON cp.concod = con.concod
					  	  JOIN credigy_parcela cpp ON con.concod = cpp.creparconref
					  	  JOIN contrato_parcela cppp ON cpp.creparseq = cppp.conparseq -- Parcelas Originais.
					 WHERE ch.procod = 28
					 [FILTRO_CARTEIRA]
					),
					 valor_acordo AS (
					SELECT sum(conparvallan) valor_acordo,
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
					  	  JOIN contrato_parcela_calculo cpc ON cra.conparseq = cpc.conparseq AND cpc.conparcalati = 0
					      JOIN fase_periodo fp ON cra.dias_atraso BETWEEN fp.dias_inicio AND fp.dias_fim
					 WHERE cpc.tipenccod >= 6000
					   AND cra.registro_base = 1';
	        ELSE 
	        -- Visão Assessoria.
		       _filtroVisaoRelatorio := '
					SELECT ch.conparvalsal,
						   ch.conparseq,
						   con.devcod,
						   con.carcod,
						   ([FILTRO_DATA_CALCULO] - cp.conpardatven) dias_atraso,
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
					   AND cra.registro_base = 1';
			        END IF;
     
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
			 cobranca_ultimo_registro AS (
			SELECT ch.cobhisdatinc::date,
				   ch.conparseq,
				   ch.conparati,
				   ch.conpardatinc,
				   CASE WHEN trim(cpd.conpardetcar) = ''SIM'' THEN ch.conpardatven - 360 ELSE ch.conpardatven END, -- Parcela de prejuízo adiciona 360 dias ao atraso.
				   ch.conparvallan,
				   ch.conparvalsal,
				   ch.carcod,
				   ch.procod,
				   ch.cobhismovtip,
				   ch.cobhismovcod,
				   ch.conparacocod,
				   row_number() OVER (PARTITION BY ch.conparseq ORDER BY ch.cobhisseq DESC) registro_base
			  FROM cobranca_historico ch 
			  	  JOIN data_referencia dr ON ch.cobhisdatinc::date BETWEEN dr.data_inicial AND dr.data_final
				  LEFT JOIN contrato_parcela_detalhe cpd ON cpd.conparseq = ch.conparseq AND cpd.conpardetcod = 30 -- Parcela de prejuízo adiciona 360 dias ao atraso.
			 WHERE TRUE 
			   [FILTRO_CARTEIRA]
			   [FILTRO_PRODUTO]
               [FILTRO_AJUIZADO]
			),
			 cobranca_registro AS (
			SELECT *,
				   ([FILTRO_DATA_CALCULO] - c.conpardatven) dias_atraso
			  FROM cobranca_ultimo_registro c
			 WHERE c.registro_base = 1 
			   AND c.conparvalsal > 0
			   AND c.conparati = 0
			),
			 valor_carteira_total AS (
			SELECT cr.conparvalsal,
				   cr.conparseq,
				   cr.procod,
				   fp.faixa
			  FROM cobranca_registro cr 
			  	  JOIN fase_periodo fp ON cr.dias_atraso BETWEEN fp.dias_inicio AND fp.dias_fim
			 WHERE TRUE /* cr.registro_base = 1 */
			   [FILTRO_REGRA_VENCIMENTO]
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
		     [FILTRO_VISAO_RELATORIO]
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
			SELECT cpr.conparretvallan,
				   cpr.tipenccod,
				   fp.faixa
			  FROM cobranca_historico ch 
			  	  JOIN contrato_parcela_retomada cpr ON ch.conparseq = cpr.conparseq AND cpr.conparretati = 0 
			  	  JOIN data_referencia dr ON cpr.conparretdatinc::date BETWEEN dr.data_inicial AND dr.data_final
			  	  JOIN fase_periodo fp ON ([FILTRO_DATA_CALCULO] - ch.conpardatven) BETWEEN fp.dias_inicio AND fp.dias_fim
	         [FILTRO_CARTEIRA]
	         [FILTRO_PRODUTO_RETOMADA]
			),
			 valor_retomada AS (
			SELECT (sum(crr.conparretvallan) FILTER (WHERE crr.tipenccod <= 5000)) - COALESCE((sum(crr.conparretvallan) FILTER (WHERE crr.tipenccod >= 6001)), 0) valor_retomada,
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
		    ORDER BY sequencia)'; 
     END IF;
    
	 _query := REPLACE(_query, '[FILTRO_VISAO_RELATORIO]', _filtroVisaoRelatorio);
	 _query := REPLACE(_query, '[FILTRO_REGRA_VENCIMENTO]', _filtroRegraVencimento);
	 _query := REPLACE(_query, '[FILTRO_DATA_CALCULO]', _filtroDataCalculo);
	 _query := REPLACE(_query, '[FILTRO_DATA_ATRASO]', _filtroDataAtraso);
	 _query := REPLACE(_query, '[FILTRO_PRODUTO_RETOMADA]', _filtroProdutoRetomada); 
	 _query := REPLACE(_query, '[FILTRO_PRODUTO]', _filtroProduto);
	 _query := REPLACE(_query, '[FILTRO_CARTEIRA]', _filtroCarteira);
	 _query := REPLACE(_query, '[FILTRO_DATA]', _filtroPeriodo);
	 _query := REPLACE(_query, '[FILTRO_FASE]', _filtroFase);
	 _query := REPLACE(_query, '[FILTRO_AJUIZADO]', _filtroAjuizado);
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
