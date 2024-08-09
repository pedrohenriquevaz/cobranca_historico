-- DROP FUNCTION public.cobranca_historico_gravar();

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
    _timeCancel TIMESTAMP without time zone := '0001-01-01 00:00:00.000';
    _functionCancel INT := 0;
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
	   	 _timeCancel := clock_timestamp();
	   	 _functionCancel := 1;
	   
		 INSERT INTO log_execucao (logexedes, logexeobj, logexeusu, logexedatini, logexedathorini, logexedathorfin, logexedathorcan, logexeusucan, logexecan) 
		 VALUES (_messageError, _functionName, _user, _date, _timeStart, _timeEnd, _timeCancel, _user, _functionCancel); 	
	   	 
	   	 TRUNCATE cobranca_historico;
	   END IF;
	 ELSE
	 
	  -- Leitura de parcelas novas 
	 PERFORM cobranca_historico_criar_parcela();
	 
	 -- Leitura de parcelas com registro de histórico existente;
	 FOR _recordData IN (
	     SELECT cp.conparseq,
				cp.conpardatven,
				ch.conpardatven conpardatvenhis,
				cp.conparvalsal,
				ch.conparvalsal conparvalsalhis,
				cp.conparvallan,
				ch.conparvallan conparvallanhis,
				con.carcod, 
				ch.carcod carcodhis,
				con.procod, 
				ch.procod procodhis
          FROM contrato con 
			  JOIN contrato_parcela cp ON con.concod = cp.concod
			  JOIN LATERAL (SELECT ch.conpardatven, 
		 						   ch.conparvallan, 
		 						   ch.conparvalsal,
		 						   ch.carcod,
		 						   ch.procod
		 					  FROM cobranca_historico ch
		 					 WHERE ch.conparseq = cp.conparseq
		 					 ORDER BY ch.cobhisseq DESC
				 		     LIMIT 1) ch ON TRUE)                           
     LOOP
	     IF _recordData.conparvallan <> _recordData.conparvallanhis THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 2);

	     ELSEIF _recordData.conparvalsal <> _recordData.conparvalsalhis THEN 
	       PERFORM cobranca_historico_atualizacao_saldo(_recordData.conparseq);	     
	     
	     ELSEIF _recordData.conpardatven <> _recordData.conpardatvenhis THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 4);
	      
	     ELSEIF _recordData.carcod <> _recordData.carcodhis THEN  
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 5);
	     
	     ELSEIF _recordData.procod <> _recordData.procodhis THEN 
	       PERFORM cobranca_historico_atualizacao(_recordData.conparseq, 6);
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
    _timeCancel := clock_timestamp();
    _functionCancel := 1;
    _messageError := SQLERRM;
	
	INSERT INTO log_execucao (logexedes, logexeobj, logexeusu, logexedatini, logexedathorini, logexedathorfin, logexedathorcan, logexeusucan, logexecan) 
	VALUES (_messageError, _functionName, _user, _date, _timeStart, _timeEnd, _timeCancel, _user, _functionCancel); 	

	RETURN _messageError;
END;
$function$
;
