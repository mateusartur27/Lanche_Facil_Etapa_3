// Servidor REST para desenvolvimento local.
//
// Usa o json-server: cada lista do arquivo db.json vira um recurso REST
// (GET, POST, PUT e DELETE em /produtos e /pedidos) e as alterações ficam
// gravadas no próprio db.json.
//
// Opções de desenvolvimento:
//   node server.js --resetar        → volta o db.json ao cardápio inicial
//   node server.js --porta 3001     → usa outra porta
const fs = require('fs');
const os = require('os');
const path = require('path');
const jsonServer = require('json-server');

const args = process.argv.slice(2);
const option = (name) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
};

// Cria o db.json a partir do cardápio inicial na primeira execução (ou com --resetar).
const dbFile = path.join(__dirname, 'db.json');
const initialFile = path.join(__dirname, 'db.inicial.json');
if (args.includes('--resetar') || !fs.existsSync(dbFile)) {
  fs.copyFileSync(initialFile, dbFile);
  console.log('db.json criado a partir de db.inicial.json');
}

const port = Number(option('--porta')) || 3000;

const server = jsonServer.create();
const router = jsonServer.router(dbFile);

// Liga CORS (necessário para o app rodando no navegador) e o log de cada requisição.
server.use(jsonServer.defaults());
server.use(jsonServer.bodyParser);

server.use(router);

// Escuta em todas as interfaces para o celular da mesma rede Wi-Fi conseguir acessar.
server.listen(port, '0.0.0.0', () => {
  console.log(`\nAPI do Lanche Fácil rodando na porta ${port}`);
  console.log(`  Navegador / Flutter Web : http://localhost:${port}/produtos`);
  console.log(`  Emulador Android        : http://10.0.2.2:${port}`);
  for (const addresses of Object.values(os.networkInterfaces())) {
    for (const address of addresses || []) {
      if (address.family === 'IPv4' && !address.internal) {
        console.log(`  Celular na mesma rede   : http://${address.address}:${port}`);
      }
    }
  }
  console.log('\nPressione Ctrl+C para parar (isso também serve para testar o modo offline).\n');
});
