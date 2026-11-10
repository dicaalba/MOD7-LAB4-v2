// Datos totalmente ficticios. NO persiste cuentas. Modificar ENABLE_POST para el propuesto.
export const ENABLE_POST = true;
const clientes = {
  CLI001: [{ numeroCuenta: '1000000001', tipo: 'AHORROS', moneda: 'PEN', titular: 'Ana Pérez (ficticio)', saldo: 100.0 }],
  CLI002: [{ numeroCuenta: '1000000002', tipo: 'CORRIENTE', moneda: 'USD', titular: 'Otro cliente', saldo: 200.0 }]
};
const headers = { 'content-type': 'application/json', 'access-control-allow-origin': '*', 'access-control-allow-headers': 'Content-Type,x-api-key', 'access-control-allow-methods': 'GET,POST,OPTIONS' };
const respond = (statusCode, value) => ({statusCode, headers, body: JSON.stringify(value)});
export const handler = async (event) => {
  const id = event.pathParameters?.['cliente-id'];
  const method = event.httpMethod;
  if (!id || !/^CLI\d{3}$/.test(id)) return respond(400, {title:'Cliente inválido',status:400,detail:'Usa CLI seguido de 3 dígitos'});
  if (method === 'GET') {
    if (!clientes[id]) return respond(404, {title:'No encontrado',status:404,detail:'Cliente inexistente'});
    return respond(200, {origen:'LAMBDA',clienteId:id,cuentas:clientes[id]});
  }
  if (method === 'POST' && ENABLE_POST) {
    let body;
    try { body = JSON.parse(event.body ?? '{}'); } catch { return respond(400, {title:'JSON inválido',status:400,detail:'El body debe ser JSON'}); }
    if (!clientes[id]) return respond(404, {title:'No encontrado',status:404,detail:'Cliente inexistente'});
    if (!['AHORROS','CORRIENTE'].includes(body.tipo) || !['PEN','USD'].includes(body.moneda) || typeof body.titular !== 'string' || !body.titular.trim())
      return respond(400, {title:'Datos inválidos',status:400,detail:'tipo, moneda y titular son obligatorios y deben ser válidos'});
    return respond(201, {numeroCuenta:'SIMULADO-0001',tipo:body.tipo,moneda:body.moneda,titular:body.titular,saldo:0,nota:'Simulación sin persistencia'});
  }
  return respond(405, {title:'Método no permitido',status:405,detail:`${method} no está habilitado`});
};
