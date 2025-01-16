import http from 'k6/http';
import { check, sleep } from 'k6';
import { WebSocket } from 'k6/experimental/websockets';

export const options = {
    stages: [
        { duration: '3s', target: 3 }, // Ramp up to 10 users
        // { duration: '1m', target: 10 }, // Hold at 10 users
        // { duration: '30s', target: 0 }, // Ramp down to 0 user
    ],
};

const DEBUG = true;
const ENV = 'dev';
const HOST = ENV === 'dev' ? 'localhost:4000' : 'try-syndicate.org';
const PROTOS = ENV === 'dev' ? '' : 's';
const ENDPOINT = `http${PROTOS}://${HOST}`;

const CODE_OPTIONS = [
    "(+ 1 2)",
    "(spawn (assert 'hello))",
    "(query/set 'hello 42)",
    "(assert 5)",
    "(retract 5)",
];

export default function () {
    const res = http.get(ENDPOINT);
    check(res, {
        'HTTP request was successful': (r) => r.status === 200,
        'CSRF token is present': (r) => r.body.includes('meta name="csrf-token"'),
    });

    const { csrfToken, phxSession, phxStatic, phxId } = extractLiveViewMetadata(res);
    const topic = `lv:${phxId}`;

    const wsUrl = `ws${PROTOS}://${HOST}/live/websocket?_csrf_token=${csrfToken}&vsn=2.0.0`;

    let curSeqNo = 0;
    const joinMessage = createJoinMessage(curSeqNo, csrfToken, topic, phxSession, phxStatic);

    const socket = new WebSocket(wsUrl, {
        headers: {
            Origin: ENDPOINT,
        }
    });

    const sendNextMessage = () => {
        curSeqNo++;
        log(`sendNextMessage, topic=${topic}, curSeqNo=${curSeqNo}`);
        const runCodeMessage = createRunCodeMessage(curSeqNo, topic, selectRandom(CODE_OPTIONS));
        log(`Sending message: ${JSON.stringify(runCodeMessage)}`);
        socket.send(JSON.stringify(runCodeMessage));
    };

    socket.onopen = () => {
        log(`WebSocket connection for ${topic} opened`);
        socket.send(JSON.stringify(joinMessage));
    };

    socket.onmessage = (message) => {
        log(`Received message: ${message.data}`);
        checkPhxResponse(message, curSeqNo);
        setTimeout(sendNextMessage, 2000);
    };

    socket.onerror = (e) => {
        log('An unexpected error occurred: ', e);
    };

    socket.onclose = () => {
        log(`WebSocket connection for ${topic} closed`);
    };

    setTimeout(() => {
        socket.close();
    }, 10000);
}

function checkPhxResponse(message, seqNo) {
    const msgJson = JSON.parse(message.data);
    check(msgJson, {
        'Response is JSON': (r) => !!r
    });
    if (msgJson) {
        check(msgJson, {
            'Response format': (r) => Array.isArray(r) && r.length >= 5,
        });
        if (msgJson[3] === 'phx_reply') {
            check(msgJson, {
                'Response status is "ok"': (r) => typeof r[4] === 'object' && r[4].status === 'ok',
            });
        }
    }
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

    log(`Extracted CSRF Token: ${csrfToken}`);

    if (!check(phxSession, { "found phx-session": (str) => !!str })) {
        fail("session token not found");
    }

    if (!check(phxStatic, { "found phx-static": (str) => !!str })) {
        fail("static token not found");
    }

    return { csrfToken, phxSession, phxStatic, phxId };
}

function createJoinMessage(seqNo, csrfToken, topic, phxSession, phxStatic) {
    return encodeMsg(null, seqNo, topic, "phx_join", {
        url: ENDPOINT,
        params: {
            _csrf_token: csrfToken,
            _mounts: 0,
        },
        session: phxSession,
        static: phxStatic,
    });
}

function createRunCodeMessage(seqNo, topic, code) {
    return encodeMsg(null, seqNo, topic, "event", {
        type: "form",
        event: "run_code",
        value: `code=${encodeURIComponent(code)}`,
    });
}

function encodeMsg(id, seq, topic, event, msg) {
    return [`${id}`, `${seq}`, topic, event, msg];
}

function selectRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function log(...args) {
    if (DEBUG) {
        console.log(...args);
    }
}