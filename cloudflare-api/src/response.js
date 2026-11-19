export const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

export function json(body, status = 200) {
  return Response.json(body, { status, headers });
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function readBody(request, limit) {
  if (Number(request.headers.get('Content-Length')) > limit) {
    throw new ApiError(413, 'O arquivo excede o limite de 1 MiB.');
  }

  const reader = request.body?.getReader();
  if (!reader) throw new ApiError(400, 'Envie os dados da operação.');
  const parts = [];
  let size = 0;

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      throw new ApiError(413, 'O conteúdo excede o limite permitido.');
    }
    parts.push(value);
  }

  return new Response(new Blob(parts), {
    headers: { 'Content-Type': request.headers.get('Content-Type') ?? '' },
  });
}
