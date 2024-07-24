CREATE TABLE cobranca_historico (
	cobhisseq BIGSERIAL PRIMARY KEY,
	cobhisdatinc TIMESTAMP WITHOUT TIME ZONE DEFAULT clock_timestamp(),
	conparseq BIGINT REFERENCES contrato_parcela(conparseq) NOT NULL,
	conparati SMALLINT NOT NULL,
	conpardatinc TIMESTAMP NOT NULL,
	conpardatven DATE NULL,
	conparvallan NUMERIC(12, 2) NULL,
	conparvalsal NUMERIC(12, 2) NULL,
	carcod BIGINT REFERENCES carteira(carcod) NOT NULL,
	procod INT REFERENCES produto(procod) NOT NULL,
	cobhismovtip SMALLINT REFERENCES cobranca_historico_movimentacao_tipo(cobhismovtip) DEFAULT 0,
	cobhismovcod BIGINT DEFAULT 0,
        conparacocod BIGINT DEFAULT 0
);

-- Caso necessite remover restrições de chave estrangeira:
ALTER TABLE cobranca_historico DROP CONSTRAINT cobranca_historico_conparseq_fkey;
ALTER TABLE cobranca_historico DROP CONSTRAINT cobranca_historico_carcod_fkey;
ALTER TABLE cobranca_historico DROP CONSTRAINT cobranca_historico_procod_fkey;
ALTER TABLE cobranca_historico ADD COLUMN conparacocod bigint DEFAULT 0;
