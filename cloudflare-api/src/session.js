import { ApiError, json, readBody } from './response.js';

const encoder = new TextEncoder();
const sessionLifetime = 24 * 60 * 60 * 1000;
const hex = (bytes) => Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');

async function hashToken(token) {
  return hex(new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(token))));
}

// Deriva o hash da senha com PBKDF2 e um sal gerado para cada conta.
async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  return new Uint8Array(await crypto.subtle.deriveBits({
    name: 'PBKDF2',
    salt: encoder.encode(salt),
    iterations: 100000,
    hash: 'SHA-256',
  }, key, 256));
}

export async function createSession(request, env, signup) {
  const { success } = await env.AUTH_LIMIT.limit({
    key: request.headers.get('CF-Connecting-IP') ?? 'local',
  });
  if (!success) throw new ApiError(429, 'Muitas tentativas. Aguarde um minuto.');

  const body = await readBody(request, 4096);
  const fields = await body.json().catch(() => null);
  const email = typeof fields?.email === 'string' ? fields.email.trim().toLowerCase() : '';
  const password = typeof fields?.senha === 'string' ? fields.senha : '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 ||
      password.length < 8 || password.length > 128) {
    throw new ApiError(400, 'Informe um e-mail válido e uma senha de 8 a 128 caracteres.');
  }

  let user;
  // O cadastro insere a conta no D1 e retorna 409 quando o e-mail já está cadastrado.
  if (signup) {
    const id = crypto.randomUUID();
    const salt = hex(crypto.getRandomValues(new Uint8Array(16)));
    const hash = hex(await passwordHash(password, salt));
    user = await env.DB.prepare(
      `INSERT INTO usuarios (id, email, sal, hash_senha)
       VALUES (?, ?, ?, ?) ON CONFLICT(email) DO NOTHING RETURNING id, email, perfil`,
    ).bind(id, email, salt, hash).first();
    if (!user) throw new ApiError(409, 'Este e-mail já está cadastrado. Use a opção Entrar.');
  } else {
    // O login consulta a conta no banco e compara o hash calculado com o armazenado.
    user = await env.DB.prepare('SELECT * FROM usuarios WHERE email = ?').bind(email).first();
    const actual = await passwordHash(password, user?.sal ?? '0'.repeat(32));
    const expected = new Uint8Array(
      (user?.hash_senha ?? '0'.repeat(64)).match(/../g).map((byte) => parseInt(byte, 16)),
    );
    if (!crypto.subtle.timingSafeEqual(actual, expected) || !user) {
      throw new ApiError(401, 'E-mail ou senha incorretos.');
    }
  }

  // O cliente recebe o token aleatório. O D1 guarda o hash e o prazo de validade.
  const token = hex(crypto.getRandomValues(new Uint8Array(32)));
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM sessoes WHERE usuario_id = ? AND expira_em <= ?').bind(user.id, now),
    env.DB.prepare('INSERT INTO sessoes VALUES (?, ?, ?)').bind(await hashToken(token), user.id, now + sessionLifetime),
  ]);
  return json({ token, email: user.email, perfil: user.perfil });
}

// Confere se o token Bearer corresponde a uma sessão vigente e recupera o perfil.
export async function authenticate(request, db) {
  const token = request.headers.get('Authorization')?.match(/^Bearer ([a-f0-9]{64})$/i)?.[1];
  if (!token) throw new ApiError(401, 'Entre na sua conta para continuar.');

  const session = await db.prepare(
    `SELECT usuarios.id, usuarios.email, usuarios.perfil, sessoes.token_hash
     FROM sessoes JOIN usuarios ON usuarios.id = sessoes.usuario_id
     WHERE sessoes.token_hash = ? AND sessoes.expira_em > ?`,
  ).bind(await hashToken(token), Date.now()).first();

  if (!session) throw new ApiError(401, 'Sua sessão expirou ou foi encerrada. Entre novamente.');
  return session;
}

// Apaga a sessão no banco para que o mesmo token deixe de autorizar requisições.
export async function revokeSession(db, session) {
  await db.prepare('DELETE FROM sessoes WHERE token_hash = ?').bind(session.token_hash).run();
  return json({ encerrada: true });
}
