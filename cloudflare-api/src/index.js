import { authenticate, createSession, revokeSession } from './session.js';
import { catalog, download, upload } from './catalog.js';
import { ApiError, headers, json } from './response.js';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    const path = new URL(request.url).pathname;
    const method = request.method;
    try {
      if (method === 'GET' && path === '/') {
        return json({ api: 'Lanche Fácil — Gestão do Cardápio' });
      }

      if (method === 'POST' && (path === '/auth/cadastro' || path === '/auth/login')) {
        return await createSession(request, env, path === '/auth/cadastro');
      }

      const item = path.match(/^\/produtos\/([a-z0-9-]+)\/anexos\/(foto|ficha)$/);
      const isCatalog = method === 'GET' && path === '/produtos';
      const isProfile = method === 'GET' && path === '/auth/perfil';
      const isLogout = method === 'POST' && path === '/auth/logout';
      const isAttachment = item && (method === 'GET' || method === 'POST');
      if (!isCatalog && !isProfile && !isLogout && !isAttachment) {
        throw new ApiError(404, 'Recurso não encontrado.');
      }

      const session = await authenticate(request, env.DB);
      if (isProfile) return json({ email: session.email, perfil: session.perfil });
      if (isLogout) return await revokeSession(env.DB, session);
      if (isCatalog) return await catalog(env.DB, session);

      const [, productId, kind] = item;
      if (method === 'POST') return await upload(request, env.DB, session, productId, kind);
      return await download(env.DB, session, productId, kind);
    } catch (error) {
      if (error instanceof ApiError) return json({ erro: error.message }, error.status);
      console.error('Falha no processamento da API', error.message);
      return json({ erro: 'O servidor não conseguiu concluir a operação.' }, 500);
    }
  },
};
