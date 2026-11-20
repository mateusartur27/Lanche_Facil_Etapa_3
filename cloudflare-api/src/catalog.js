import { ApiError, headers, json, readBody } from './response.js';

const maxBytes = 1024 * 1024;

const formats = {
  png: { mime: 'image/png', kind: 'foto', signature: [137, 80, 78, 71, 13, 10, 26, 10] },
  jpg: { mime: 'image/jpeg', kind: 'foto', signature: [255, 216, 255] },
  pdf: { mime: 'application/pdf', kind: 'ficha', signature: [37, 80, 68, 70, 45] },
};

// Lista os produtos e inclui apenas os metadados dos anexos da conta autenticada.
export async function catalog(db, user) {
  const { results } = await db.prepare(
    `SELECT p.json, a.tipo, a.nome, a.tamanho
     FROM produtos p LEFT JOIN anexos a ON a.produto_id = p.id AND a.usuario_id = ?
     ORDER BY json_extract(p.json, '$.nome'), a.tipo`,
  ).bind(user.id).all();

  const products = new Map();
  for (const row of results) {
    const product = JSON.parse(row.json);
    if (!products.has(product.id)) products.set(product.id, { ...product, anexos: {} });
    if (row.tipo) products.get(product.id).anexos[row.tipo] = { nome: row.nome, tamanho: row.tamanho };
  }
  return json([...products.values()]);
}

export async function upload(request, db, user, productId, kind) {
  // A API verifica a permissão mesmo quando o pedido é feito fora da tela do app.
  if (user.perfil !== 'funcionario') {
    throw new ApiError(403, 'Seu perfil pode consultar o cardápio. O envio exige permissão de funcionário.');
  }

  const product = await db.prepare('SELECT id FROM produtos WHERE id = ?').bind(productId).first();
  if (!product) throw new ApiError(404, 'Produto não encontrado.');

  // O limite do corpo inclui espaço para os cabeçalhos e separadores do multipart.
  const body = await readBody(request, maxBytes + 8192);
  const data = await body.formData().catch(() => null);
  const [file] = data?.getAll('arquivo') ?? [];
  if (!(file instanceof File) || !file.size || data.getAll('arquivo').length !== 1) {
    throw new ApiError(400, 'Selecione um arquivo para enviar.');
  }
  if (file.size > maxBytes) throw new ApiError(413, 'O arquivo excede o limite de 1 MiB.');

  const name = file.name.split(/[\\/]/).at(-1).replace(/[\u0000-\u001f\u007f]/g, '').trim();
  const suffix = name.toLowerCase().match(/\.(png|jpe?g|pdf)$/)?.[1];
  const format = formats[suffix === 'jpeg' ? 'jpg' : suffix];
  if (!format || format.kind !== kind || name.length > 160) {
    throw new ApiError(415, 'Selecione uma foto PNG/JPG ou uma ficha técnica PDF na opção correspondente.');
  }

  // Confere a assinatura inicial do arquivo além da extensão e do tipo de anexo.
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (!format.signature.every((byte, index) => bytes[index] === byte)) {
    throw new ApiError(415, 'O conteúdo do arquivo não corresponde ao formato informado.');
  }

  // Mantém uma foto e uma ficha por produto e conta. Um novo envio substitui o anterior do mesmo tipo.
  await db.prepare(
    `INSERT INTO anexos (usuario_id, produto_id, tipo, nome, mime, tamanho, dados)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(usuario_id, produto_id, tipo) DO UPDATE SET
       nome = excluded.nome, mime = excluded.mime, tamanho = excluded.tamanho, dados = excluded.dados`,
  ).bind(user.id, productId, kind, name, format.mime, file.size, bytes.buffer).run();
  return json({ nome: name, tamanho: file.size });
}

// Busca os bytes pelo produto, tipo de anexo e conta autenticada.
export async function download(db, user, productId, kind) {
  const attachment = await db.prepare(
    'SELECT dados, mime FROM anexos WHERE usuario_id = ? AND produto_id = ? AND tipo = ?',
  ).bind(user.id, productId, kind).first();
  if (!attachment) throw new ApiError(404, 'Nenhum arquivo foi enviado nesta conta para este produto.');

  return new Response(new Uint8Array(attachment.dados), {
    headers: { ...headers, 'Content-Type': attachment.mime, 'Content-Disposition': 'attachment' },
  });
}
