CREATE TABLE cobranca_historico_movimentacao_tipo (
	cobhismovtip INT PRIMARY KEY,
	cobhismovdes varchar(50) NOT NULL
);

INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(7, 'ALTERACAO SALDO COM ERRO');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(6, 'ALTERACAO PRODUTO');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(5, 'ALTERACAO CARTEIRA');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(4, 'ALTERACAO VENCIMENTO');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(3, 'INCLUSAO DEVOLUCAO');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(2, 'INCLUSAO PAGAMENTO');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(1, 'ALTERACAO VALOR');
INSERT INTO public.cobranca_historico_movimentacao_tipo (cobhismovtip, cobhismovdes) VALUES(0, 'INCLUSAO PARCELA');
