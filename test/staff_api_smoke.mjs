import { strict as assert } from 'node:assert';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const api = process.env.STAFF_API_URL ?? 'https://lanche-facil-etapa3.mateus2002ns.workers.dev';
// Cria credenciais fictícias novas em cada execução para testar o cadastro real.
const email = `teste-${randomUUID()}@exemplo.test`;
const senha = `Teste-${randomUUID()}`;
const product = '/produtos/cachorro-quente/anexos';

function multipart(bytes, name) {
  const form = new FormData();
  form.append('arquivo', new Blob([bytes]), name);
  return form;
}

async function request(path, expected, { method = 'GET', token, body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(body);
  }
  const response = await fetch(api + path, { method, headers, body });
  if (response.status !== expected) {
    assert.fail(`${method} ${path}: esperava HTTP ${expected}, recebi ${response.status} ${await response.text()}`);
  }
  console.log(`${response.status} ${method} ${path}`);
  return response;
}

const png = await readFile(new URL('../assets/icons/app_icon.png', import.meta.url));
const photo = multipart(png, 'foto-de-teste.png');
const pdf = Buffer.from('%PDF-1.4\n% Arquivo fictício para verificar o transporte e a persistência.\n%%EOF\n');

// Verifica que o catálogo exige um token e que o login falha antes de criar a conta.
await request('/produtos', 401);
await request('/auth/login', 401, { method: 'POST', body: { email, senha } });
const { token, perfil } = await (await request('/auth/cadastro', 200, {
  method: 'POST', body: { email, senha },
})).json();
assert.equal(perfil, 'funcionario');

await request('/auth/perfil', 200, { token });
await request('/produtos', 200, { token });
// Verifica se a API rejeita arquivo ausente, acima do limite ou com conteúdo inválido.
await request(product + '/foto', 400, { method: 'POST', token, body: new FormData() });
await request(product + '/foto', 413, {
  method: 'POST', token, body: multipart(Buffer.alloc(1024 * 1024 + 1), 'grande.png'),
});
await request(product + '/foto', 415, {
  method: 'POST', token, body: multipart(Buffer.from('texto'), 'invalido.png'),
});
const uploaded = await (await request(product + '/foto', 200, { method: 'POST', token, body: photo })).json();
assert.deepEqual(uploaded, { nome: 'foto-de-teste.png', tamanho: png.length });
await request(product + '/ficha', 200, { method: 'POST', token, body: multipart(pdf, 'ficha-de-teste.pdf') });

// Confere os metadados e compara os bytes baixados com os mesmos bytes enviados.
const products = await (await request('/produtos', 200, { token })).json();
assert.deepEqual(products.find((item) => item.id === 'cachorro-quente').anexos.foto, uploaded);
assert.deepEqual(Buffer.from(await (await request(product + '/foto', 200, { token })).arrayBuffer()), png);
assert.deepEqual(Buffer.from(await (await request(product + '/ficha', 200, { token })).arrayBuffer()), pdf);

// Usa o perfil de consulta para confirmar o 403 no upload e o isolamento dos anexos.
if (process.env.STAFF_API_URL == null || process.env.TEST_VIEWER_PASSWORD) {
  const viewer = await (await request('/auth/login', 200, {
    method: 'POST',
    body: { email: 'consulta@lanchefacil.test', senha: process.env.TEST_VIEWER_PASSWORD ?? 'ConsultaFANS2026!' },
  })).json();
  assert.equal(viewer.perfil, 'consulta');
  await request('/produtos', 200, { token: viewer.token });
  await request(product + '/foto', 403, { method: 'POST', token: viewer.token, body: photo });
  await request(product + '/foto', 404, { token: viewer.token });
  await request('/auth/logout', 200, { method: 'POST', token: viewer.token });
}

// Testa a revogação do token e confirma que uma nova sessão recupera o arquivo salvo.
await request('/auth/logout', 200, { method: 'POST', token });
await request('/produtos', 401, { token });
const signedIn = await (await request('/auth/login', 200, { method: 'POST', body: { email, senha } })).json();
await request(product + '/foto', 200, { token: signedIn.token });
await request('/auth/logout', 200, { method: 'POST', token: signedIn.token });
console.log('Fluxo de autenticação, autorização e arquivos verificado.');
