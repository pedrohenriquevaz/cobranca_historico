CREATE TABLE public.log_execucao (
	logexeseq bigserial NOT NULL,
	logexepro int2 NOT NULL DEFAULT 1,
	logexedes varchar(10240) NOT NULL,
	logexeobj varchar(100) NOT NULL,
	logexeusu int2 NOT NULL,
	logexedatini date NOT NULL,
	logexedathorini timestamp NOT NULL,
	logexedathorfin timestamp NULL DEFAULT '0001-01-01 00:00:00'::timestamp without time zone,logexetemtot TIME NOT NULL GENERATED ALWAYS AS (CASE WHEN logexedathorfin <> '0001-01-01 00:00:00.000' THEN (logexedathorfin - logexedathorini) ELSE (logexedathorcan - logexedathorini) END) STORED;
	logexedathorcan timestamp NULL DEFAULT '0001-01-01 00:00:00'::timestamp without time zone,
	logexeusucan int2 NULL DEFAULT 0,
	logexecan int2 NULL DEFAULT 0,
	CONSTRAINT log_execucao_pkey PRIMARY KEY (logexeseq)
);

-- Novo campo para contabilizar tempo de execução:
ALTER TABLE log_execucao ADD COLUMN logexetemtot TIME NOT NULL GENERATED ALWAYS AS (CASE WHEN logexedathorfin <> '0001-01-01 00:00:00.000' THEN (logexedathorfin - logexedathorini) ELSE (logexedathorcan - logexedathorini) END) STORED;

SELECT max(logexeseq) 
  FROM log_execucao;
  
CREATE SEQUENCE logexeseq
START WITH --valor
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
NO CYCLE
CACHE 1;

ALTER TABLE log_execucao ALTER COLUMN logexeseq SET DEFAULT nextval('logexeseq'::regclass);
ALTER TABLE log_execucao ALTER COLUMN logexedathorfin SET DEFAULT '0001-01-01 00:00:00'::timestamp without time zone;
ALTER TABLE log_execucao ALTER COLUMN logexedathorcan SET DEFAULT '0001-01-01 00:00:00'::timestamp without time zone;
ALTER TABLE log_execucao ALTER COLUMN logexeusucan SET DEFAULT 0;
ALTER TABLE log_execucao ALTER COLUMN logexecan SET DEFAULT 0;
ALTER TABLE log_execucao
