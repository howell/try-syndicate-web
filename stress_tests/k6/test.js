import http from 'k6/http';
import { check, sleep } from 'k6';
import ws from 'k6/ws';

export const options = {
    stages: [
        { duration: '3s', target: 3 }, // Ramp up to 10 users
        // { duration: '1m', target: 10 }, // Hold at 10 users
        // { duration: '30s', target: 0 }, // Ramp down to 0 user
    ],
};

const ENV = 'dev';
const HOST = ENV === 'dev' ? 'localhost:4000' : 'try-syndicate.org';
const PROTOS = ENV === 'dev' ? '' : 's';
const ENDPOINT = `http${PROTOS}://${HOST}`;

export default function () {
    const res = http.get(ENDPOINT);
    check(res, {
        'HTTP request was successful': (r) => r.status === 200,
        'CSRF token is present': (r) => r.body.includes('meta name="csrf-token"'),
    });

    const { csrfToken, phxSession, phxStatic, phxId } = extractLiveViewMetadata(res);
    const topic = `lv:${phxId}`;

    const wsUrl = `ws${PROTOS}://${HOST}/live/websocket?_csrf_token=${csrfToken}&vsn=2.0.0`;

    const joinMessage = createJoinMessage(csrfToken, topic, phxSession, phxStatic);

    const response = ws.connect(wsUrl,
        {
            headers: {
                Origin: ENDPOINT,
            }
        },
        function (socket) {
            socket.on('open', function () {
                console.log(`WebSocket connection for ${topic} opened`);
                socket.send(JSON.stringify(joinMessage));
                console.log('Join message sent');
            });

            socket.on('message', function (message) {
                console.log(`Received message: ${message}`);
            });

            socket.on('error', function (e) {
                if (e.error() != 'websocket: close sent') {
                    console.error('An unexpected error occured: ', e.error());
                }
            });

            socket.on('close', function () {
                console.log(`WebSocket connection for ${topic} closed`);
            });

            sleep(2);
            socket.close();
        });

    if (response.error !== '')
        console.log(`WebSocket error: ${response.error}`);

    check(response, {
        'WebSocket connection was successful': (r) => r && r.status === 101,
    });
}

function extractLiveViewMetadata(response) {
    const body = response.html();
    const csrfTokenMatch = body.find("meta[name='csrf-token']");
    const csrfToken = csrfTokenMatch ? csrfTokenMatch.attr('content') : null;
    const elem = body.find("div[data-phx-main]");
    const phxSession = elem.data("phx-session");
    const phxStatic = elem.data("phx-static");
    const phxId = elem.attr("id");

    if (!check(csrfToken, { "found WS token ": (token) => !!token })) {
        fail("websocket csrf token not found");
    }

    console.log(`Extracted CSRF Token: ${csrfToken}`);

    if (!check(phxSession, { "found phx-session": (str) => !!str })) {
        fail("session token not found");
    }

    if (!check(phxStatic, { "found phx-static": (str) => !!str })) {
        fail("static token not found");
    }

    return { csrfToken, phxSession, phxStatic, phxId };
}

function createJoinMessage(csrfToken, topic, phxSession, phxStatic) {
    return encodeMsg(null, 0, topic, "phx_join", {
        url: ENDPOINT,
        params: {
            _csrf_token: csrfToken,
            _mounts: 0,
        },
        session: phxSession,
        static: phxStatic,
    });
}

function encodeMsg(id, seq, topic, event, msg) {
    return [`${id}`, `${seq}`, topic, event, msg];
}