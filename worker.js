import { connect } from 'cloudflare:sockets';

// تمام تنظیمات از قبل برای شما اعمال شده است:
const userID = 'd342d11e-d424-4583-b36e-524ab1f0afa4';
const proxyIP = 'bpb.yousef.isegaro.com';

export default {
  async fetch(request) {
    const upgradeHeader = request.headers.get('Upgrade');
    const url = new URL(request.url);

    // اگر لینک ورکر را در مرورگر باز کنید، ۵ کانفیگ آماده اختصاصی شما را نمایش می‌دهد:
    if (!upgradeHeader || upgradeHeader !== 'websocket') {
      const host = url.hostname;
      const cleanIPs = [
        { ip: 'www.speedtest.net', name: 'VIP-1' },
        { ip: '162.159.135.42', name: 'VIP-2' },
        { ip: '104.18.2.161', name: 'VIP-3' },
        { ip: '172.66.44.106', name: 'VIP-4' },
        { ip: '104.17.147.22', name: 'VIP-5' }
      ];

      const configs = cleanIPs.map(item =>
        `vless://${userID}@${item.ip}:443?encryption=none&security=tls&sni=${host}&fp=chrome&type=ws&host=${host}&path=%2F%3Fed%3D2048#${item.name}`
      ).join('\n');

      return new Response(configs + '\n', {
        status: 200,
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
      });
    }

    // منطق اصلی اتصال VLESS روی WebSocket
    return await handleVlessWebSocket(request);
  },
};

async function handleVlessWebSocket(request) {
  const webSocketPair = new WebSocketPair();
  const [client, webSocket] = Object.values(webSocketPair);
  webSocket.accept();

  const earlyDataHeader = request.headers.get('sec-websocket-protocol') || '';
  const readableWebSocketStream = makeReadableWebSocketStream(webSocket, earlyDataHeader);

  let remoteSocketWrapper = { value: null };
  let isDns = false;

  readableWebSocketStream.pipeTo(new WritableStream({
    async write(chunk) {
      if (remoteSocketWrapper.value) {
        const writer = remoteSocketWrapper.value.writable.getWriter();
        await writer.write(chunk);
        writer.releaseLock();
        return;
      }

      const {
        hasError,
        addressRemote = '',
        portRemote = 443,
        rawDataIndex,
        vlessVersion = new Uint8Array([0, 0]),
        isUDP,
      } = processVlessHeader(chunk, userID);

      if (hasError) return;
      if (isUDP && portRemote !== 53) return;

      const vlessResponseHeader = new Uint8Array([vlessVersion[0], 0]);
      const rawClientData = chunk.slice(rawDataIndex);

      await handleTCPOutBound(
        remoteSocketWrapper,
        addressRemote,
        portRemote,
        rawClientData,
        webSocket,
        vlessResponseHeader
      );
    },
  })).catch(() => {});

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
}

async function handleTCPOutBound(remoteSocket, addressRemote, portRemote, rawClientData, webSocket, vlessResponseHeader) {
  async function connectAndWrite(address, port) {
    const tcpSocket = connect({ hostname: address, port: port });
    remoteSocket.value = tcpSocket;
    const writer = tcpSocket.writable.getWriter();
    await writer.write(rawClientData);
    writer.releaseLock();
    return tcpSocket;
  }

  async function retryWithProxy() {
    try {
      const tcpSocket = await connectAndWrite(proxyIP || addressRemote, portRemote);
      tcpSocket.closed.catch(() => {}).finally(() => safeCloseWebSocket(webSocket));
      remoteSocketToWS(tcpSocket, webSocket, vlessResponseHeader, null);
    } catch (_) {
      safeCloseWebSocket(webSocket);
    }
  }

  try {
    const tcpSocket = await connectAndWrite(addressRemote, portRemote);
    remoteSocketToWS(tcpSocket, webSocket, vlessResponseHeader, retryWithProxy);
  } catch (_) {
    await retryWithProxy();
  }
}

function makeReadableWebSocketStream(webSocketServer, earlyDataHeader) {
  let readableStreamCancel = false;
  return new ReadableStream({
    start(controller) {
      webSocketServer.addEventListener('message', (event) => {
        if (!readableStreamCancel) controller.enqueue(event.data);
      });
      webSocketServer.addEventListener('close', () => {
        safeCloseWebSocket(webSocketServer);
        if (!readableStreamCancel) controller.close();
      });
      webSocketServer.addEventListener('error', (err) => {
        controller.error(err);
      });
      const { earlyData, error } = base64ToArrayBuffer(earlyDataHeader);
      if (error) controller.error(error);
      else if (earlyData) controller.enqueue(earlyData);
    },
    cancel() {
      readableStreamCancel = true;
      safeCloseWebSocket(webSocketServer);
    },
  });
}

function processVlessHeader(vlessBuffer, userID) {
  if (vlessBuffer.byteLength < 24) return { hasError: true };
  const version = new Uint8Array(vlessBuffer.slice(0, 1));
  const uuid = stringifyUUID(new Uint8Array(vlessBuffer.slice(1, 17)));
  if (uuid !== userID.toLowerCase()) return { hasError: true };

  const optLength = new Uint8Array(vlessBuffer.slice(17, 18))[0];
  const command = new Uint8Array(vlessBuffer.slice(18 + optLength, 18 + optLength + 1))[0];
  const isUDP = command === 2;
  if (command !== 1 && command !== 2) return { hasError: true };

  const portIndex = 18 + optLength + 1;
  const portRemote = new DataView(vlessBuffer.slice(portIndex, portIndex + 2)).getUint16(0);

  let addressIndex = portIndex + 2;
  const addressType = new Uint8Array(vlessBuffer.slice(addressIndex, addressIndex + 1))[0];
  let addressLength = 0;
  let addressValueIndex = addressIndex + 1;
  let addressValue = '';

  switch (addressType) {
    case 1:
      addressLength = 4;
      addressValue = new Uint8Array(vlessBuffer.slice(addressValueIndex, addressValueIndex + addressLength)).join('.');
      break;
    case 2:
      addressLength = new Uint8Array(vlessBuffer.slice(addressValueIndex, addressValueIndex + 1))[0];
      addressValueIndex += 1;
      addressValue = new TextDecoder().decode(vlessBuffer.slice(addressValueIndex, addressValueIndex + addressLength));
      break;
    case 3:
      addressLength = 16;
      const dataView = new DataView(vlessBuffer.slice(addressValueIndex, addressValueIndex + addressLength));
      const ipv6 = [];
      for (let i = 0; i < 8; i++) ipv6.push(dataView.getUint16(i * 2).toString(16));
      addressValue = ipv6.join(':');
      break;
    default:
      return { hasError: true };
  }

  return {
    hasError: false,
    addressRemote: addressValue,
    portRemote,
    rawDataIndex: addressValueIndex + addressLength,
    vlessVersion: version,
    isUDP,
  };
}

async function remoteSocketToWS(remoteSocket, webSocket, vlessResponseHeader, retry) {
  let vlessHeader = vlessResponseHeader;
  let hasIncomingData = false;
  await remoteSocket.readable.pipeTo(
    new WritableStream({
      async write(chunk) {
        hasIncomingData = true;
        if (webSocket.readyState !== 1) return;
        if (vlessHeader) {
          webSocket.send(await new Blob([vlessHeader, chunk]).arrayBuffer());
          vlessHeader = null;
        } else {
          webSocket.send(chunk);
        }
      },
    })
  ).catch(() => safeCloseWebSocket(webSocket));

  if (!hasIncomingData && retry) {
    await retry();
  }
}

function base64ToArrayBuffer(base64Str) {
  if (!base64Str) return { error: null };
  try {
    base64Str = base64Str.replace(/-/g, '+').replace(/_/g, '/');
    const decode = atob(base64Str);
    const arryBuffer = Uint8Array.from(decode, (c) => c.charCodeAt(0));
    return { earlyData: arryBuffer.buffer, error: null };
  } catch (error) {
    return { error };
  }
}

function safeCloseWebSocket(socket) {
  try {
    if (socket.readyState === 1 || socket.readyState === 2) socket.close();
  } catch (_) {}
}

const byteToHex = [];
for (let i = 0; i < 256; ++i) byteToHex.push((i + 256).toString(16).slice(1));

function stringifyUUID(arr, offset = 0) {
  return (
    byteToHex[arr[offset + 0]] + byteToHex[arr[offset + 1]] + byteToHex[arr[offset + 2]] + byteToHex[arr[offset + 3]] + '-' +
    byteToHex[arr[offset + 4]] + byteToHex[arr[offset + 5]] + '-' +
    byteToHex[arr[offset + 6]] + byteToHex[arr[offset + 7]] + '-' +
    byteToHex[arr[offset + 8]] + byteToHex[arr[offset + 9]] + '-' +
    byteToHex[arr[offset + 10]] + byteToHex[arr[offset + 11]] + byteToHex[arr[offset + 12]] + byteToHex[arr[offset + 13]] + byteToHex[arr[offset + 14]] + byteToHex[arr[offset + 15]]
  ).toLowerCase();
}
