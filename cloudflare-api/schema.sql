CREATE TABLE IF NOT EXISTS produtos (
  id TEXT PRIMARY KEY,
  json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS usuarios (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  sal TEXT NOT NULL,
  hash_senha TEXT NOT NULL,
  perfil TEXT NOT NULL DEFAULT 'funcionario' CHECK (perfil IN ('funcionario', 'consulta'))
);

CREATE TABLE IF NOT EXISTS sessoes (
  token_hash TEXT PRIMARY KEY,
  usuario_id TEXT NOT NULL REFERENCES usuarios(id),
  expira_em INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessoes_usuario ON sessoes (usuario_id, expira_em);

CREATE TABLE IF NOT EXISTS anexos (
  usuario_id TEXT NOT NULL REFERENCES usuarios(id),
  produto_id TEXT NOT NULL REFERENCES produtos(id),
  tipo TEXT NOT NULL CHECK (tipo IN ('foto', 'ficha')),
  nome TEXT NOT NULL,
  mime TEXT NOT NULL,
  tamanho INTEGER NOT NULL,
  dados BLOB NOT NULL,
  PRIMARY KEY (usuario_id, produto_id, tipo)
);

INSERT OR IGNORE INTO produtos (id, json) VALUES
('cachorro-quente', '{"id":"cachorro-quente","estabelecimentoId":"campus-principal","nome":"Cachorro-quente","descricao":"Pão, salsicha, molho, milho, batata palha e complementos.","preco":1400,"categoria":"Lanches","ativo":true,"disponivel":true,"estoque":18,"imagemUrl":null,"ajusteImagem":"contain","criadoEm":"2026-08-16T00:00:00.000","atualizadoEm":"2026-08-16T00:00:00.000"}'),
('refrigerante', '{"id":"refrigerante","estabelecimentoId":"campus-principal","nome":"Refrigerante lata","descricao":"Lata de 350 ml servida gelada.","preco":600,"categoria":"Bebidas","ativo":true,"disponivel":true,"estoque":24,"imagemUrl":null,"ajusteImagem":"contain","criadoEm":"2026-08-16T00:00:00.000","atualizadoEm":"2026-08-16T00:00:00.000"}'),
('salgado', '{"id":"salgado","estabelecimentoId":"campus-principal","nome":"Salgado assado","descricao":"Opções de frango, presunto e queijo conforme disponibilidade.","preco":900,"categoria":"Salgados","ativo":true,"disponivel":true,"estoque":30,"imagemUrl":null,"ajusteImagem":"contain","criadoEm":"2026-08-16T00:00:00.000","atualizadoEm":"2026-08-16T00:00:00.000"}'),
('trident', '{"id":"trident","estabelecimentoId":"campus-principal","nome":"Trident","descricao":"Goma de mascar em sabores variados.","preco":350,"categoria":"Conveniência","ativo":true,"disponivel":true,"estoque":40,"imagemUrl":null,"ajusteImagem":"contain","criadoEm":"2026-08-16T00:00:00.000","atualizadoEm":"2026-08-16T00:00:00.000"}'),
('x-salada', '{"id":"x-salada","estabelecimentoId":"campus-principal","nome":"X-Salada especial","descricao":"Hambúrguer, queijo, salada fresca e molho da casa.","preco":1800,"categoria":"Lanches","ativo":true,"disponivel":true,"estoque":15,"imagemUrl":null,"ajusteImagem":"contain","criadoEm":"2026-08-16T00:00:00.000","atualizadoEm":"2026-08-16T00:00:00.000"}');
