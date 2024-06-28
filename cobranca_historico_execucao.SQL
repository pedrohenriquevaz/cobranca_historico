CREATE OR REPLACE FUNCTION public.cobranca_historico_execucao(_executiontype integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE 
    _return TEXT := '';
    _lastTimeExecution timestamp WITHOUT time ZONE := '0001-01-01 00:00:00.000';
    _objectName TEXT := 'cobranca_historico_gravar()';
BEGIN     
   
    IF _executionType = 1 THEN 
    	SELECT cobranca_historico_gravar()
	      INTO _return;
	END IF;

	IF _executionType = 2 THEN 
	   SELECT l.logexedathorfin
	     INTO _lastTimeExecution
	     FROM log_execucao l 
	    WHERE l.logexeobj = _objectName
	    ORDER BY logexeseq DESC 
	    LIMIT 1;
	   
	   IF _lastTimeExecution = '0001-01-01 00:00:00.000' THEN 
	     RAISE NOTICE 'Verificação correta.';
	     
	     SELECT cobranca_historico_gravar()
	       INTO _return;
	   ELSE
	   	 _return := 'Primeira chamada da função foi executada com sucesso, cancelando execução atual.';
	   END IF;
	END IF;

    RETURN _return;

EXCEPTION 
	WHEN OTHERS THEN 
    RETURN SQLERRM;
END;
$function$
;
