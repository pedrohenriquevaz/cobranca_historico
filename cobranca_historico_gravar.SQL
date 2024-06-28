CREATE OR REPLACE FUNCTION public.cobranca_historico_gravar()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    _messageError TEXT := '';
    _user INT := 9999;
    _functionName TEXT := 'cobranca_historico_gravar()';
	_countHistory INT := 0;
    _count INT := 0;
    _countRetry INT := 0;
    _message TEXT := '';
    _date DATE := current_date;
    _timeStart TIMESTAMP without time zone := clock_timestamp();
    _timeEnd TIMESTAMP without time zone := '0001-01-01 00:00:00.000';
    _recordData RECORD;
BEGIN 
	
	SELECT count(*)
	  INTO _countHistory 
	  FROM cobranca_historico ch;
	 
	IF _countHistory = 0 THEN 
	  SELECT count(*)
	    INTO _count 
	    FROM contrato_parcela cp 
	   WHERE cp.conparvalsal > 0
	     AND cp.conparati <> 1;
	   
	   SELECT cobranca_historico_criar()
	     INTO _countHistory;
	    
	   IF _countHistory <> _count THEN 
	   	 _messageError := 'A quantidade de parcelas inseridas é diferente da quantidade de parcelas ativas.';
	   
	   	 INSERT INTO log_execucao (logexedes, logexeobj, logexeusu, logexedatini, logexedathorini, logexedathorfin) 
		 VALUES (_messageError, _functionName, _user, _date, _timeStart, _timeEnd);
	   	 
	   	 TRUNCATE cobranca_historico;
	   END IF;
	 ELSE
	 
	  -- Leitura de parcelas novas 
	 PERFORM cobranca_historico_criar_parcela();
	 
	 -- Leitura de parcelas com registro de histórico existente;
	 FOR _recordData IN (
	     SELECT cp.conparseq,
				ARRAY[cp.conpardatven, ch.conpardatven] conpardatven,
				ARRAY[cp.conparvalsal, ch.conparvalsal] conparvalsal,
				ARRAY[con.carcod, ch.carcod] carcod,
				ARRAY[con.procod, ch.procod] procod
          FROM contrato con 
			  JOIN contrato_parcela cp ON con.concod = cp.concod
			  JOIN LATERAL (SELECT ch.conparseq, 
		 						   ch.conparati, 
		 						   ch.conpardatven, 
		 						   ch.conparvallan, 
		 						   ch.conparvalsal,
		 						   ch.carcod,
		 						   ch.procod
		 					  FROM cobranca_historico ch
		 					 WHERE ch.conparseq = cp.conparseq
		 					 ORDER BY ch.cobhisseq DESC
				 		     LIMIT 1) ch ON TRUE)                           
     LOOP
	     
	     IF _recordData.conparvalsal[1] <> _recordData.conparvalsal[2] THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 1);
	     
	     ELSEIF _recordData.conpardatven[1] <> _recordData.conpardatven[2] THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 2);
	     
	     ELSEIF _recordData.procod[1] <> _recordData.procod[2] THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 3);
		 
	     ELSEIF _recordData.carcod[1] <> _recordData.carcod[2] THEN  
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 4);

	     END IF;
	 _message := 'Sucesso na execução.';
	    
    END LOOP;
	 
	END IF;
	
    IF _messageError = '' THEN 
      _timeEnd := clock_timestamp();
   
   	  INSERT INTO log_execucao (logexedes, logexeobj, logexeusu, logexedatini, logexedathorini, logexedathorfin) 
	  VALUES (_message, _functionName, _user, _date, _timeStart, _timeEnd); 	 
    ELSE 
      RETURN _messageError;
    END IF;
    
RETURN _message;
EXCEPTION 
	WHEN OTHERS THEN  
	
	_timeEnd := '0001-01-01 00:00:00.000';
    _messageError := SQLERRM;
	
	INSERT INTO log_execucao (logexedes, logexeobj, logexeusu, logexedatini, logexedathorini, logexedathorfin) 
	VALUES (_messageError, _functionName, _user, _date, _timeStart, _timeEnd); 	

	RETURN _messageError;
END;
$function$
;
