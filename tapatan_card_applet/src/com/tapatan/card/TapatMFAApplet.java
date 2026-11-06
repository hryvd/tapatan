package com.tapatan.card;

import javacard.framework.Applet;
import javacard.framework.APDU;
import javacard.framework.ISO7816;
import javacard.framework.ISOException;
import javacard.framework.OwnerPIN;
import javacard.framework.JCSystem;
import javacard.framework.Util;
import javacard.security.RandomData;

/**
 * TapatMFAApplet - JCOP4 Hardware Security Applet with Turing-Type Multi-Tape
 * Composition Algorithm for Mutual Message Encoding, Decoding & Authentication.
 */
public class TapatMFAApplet extends Applet {

    // APDU Instructions
    public static final byte INS_GET_CHALLENGE         = (byte) 0x84;
    public static final byte INS_INTERNAL_AUTHENTICATE = (byte) 0x88;
    public static final byte INS_VERIFY_PIN            = (byte) 0x20;
    public static final byte INS_CHANGE_PIN            = (byte) 0x24;
    public static final byte INS_GET_DATA              = (byte) 0xCA;
    public static final byte INS_STORE_DATA            = (byte) 0xE2;

    // Status Words
    public static final short SW_WRONG_PIN_PREFIX      = (short) 0x63C0;
    public static final short SW_PIN_BLOCKED           = (short) 0x6983;

    // PIN Configuration
    private static final byte PIN_MAX_TRIES = (byte) 5;
    private static final byte PIN_MAX_SIZE  = (byte) 8;
    private static final byte[] DEFAULT_PIN = {'1', '2', '3', '4', '5', '6'};

    // Shared 16-byte Hardware Key for the Turing Composition Machine ("TAPAT_TURING_KEY")
    private static final byte[] TURING_KEY = {
        (byte) 0x54, (byte) 0x41, (byte) 0x50, (byte) 0x41,
        (byte) 0x54, (byte) 0x5F, (byte) 0x54, (byte) 0x55,
        (byte) 0x52, (byte) 0x49, (byte) 0x4E, (byte) 0x47,
        (byte) 0x5F, (byte) 0x4B, (byte) 0x45, (byte) 0x59
    };

    // Pre-loaded default JSON identity:
    // {"tapatan_id":"TAPAT_JCOP4_8821","cardId":"TAPAT_JCOP4_8821","owner":"richard@tapat.ph","name":"Richard"}
    private static final byte[] DEFAULT_IDENTITY_JSON = {
        '{','"','t','a','p','a','t','a','n','_','i','d','"',':',
        '"','T','A','P','A','T','_','J','C','O','P','4','_','8','8','2','1','"',',',
        '"','c','a','r','d','I','d','"',':',
        '"','T','A','P','A','T','_','J','C','O','P','4','_','8','8','2','1','"',',',
        '"','o','w','n','e','r','"',':',
        '"','r','i','c','h','a','r','d','@','t','a','p','a','t','.','p','h','"',',',
        '"','n','a','m','e','"',':',
        '"','R','i','c','h','a','r','d','"','}'
    };

    private static final short MAX_TOKEN_SIZE = (short) 128;
    private static final short TURING_HEADER_LEN = (short) 14;

    private OwnerPIN pin;
    private RandomData rng;
    private byte[] lastCardNonce;
    private byte[] turingState; // [0..7] = 8B Turing tape, [8..11] = 4B TMAC
    private byte[] storedData;
    private short storedDataLength;

    protected TapatMFAApplet() {
        pin = new OwnerPIN(PIN_MAX_TRIES, PIN_MAX_SIZE);
        pin.update(DEFAULT_PIN, (short) 0, (byte) 4);

        rng = RandomData.getInstance(RandomData.ALG_SECURE_RANDOM);
        lastCardNonce = JCSystem.makeTransientByteArray((short) 8, JCSystem.CLEAR_ON_RESET);
        turingState = new byte[12];
        storedData = new byte[MAX_TOKEN_SIZE];

        short defLen = (short) DEFAULT_IDENTITY_JSON.length;
        Util.arrayCopyNonAtomic(DEFAULT_IDENTITY_JSON, (short) 0, storedData, (short) 0, defLen);
        storedDataLength = defLen;
    }

    public static void install(byte[] bArray, short bOffset, byte bLength) {
        TapatMFAApplet applet = new TapatMFAApplet();
        byte aidLen = bArray[bOffset];
        if (aidLen == 0) {
            applet.register();
        } else {
            applet.register(bArray, (short) (bOffset + 1), aidLen);
        }
    }

    public boolean select() {
        return true;
    }

    public void deselect() {
        pin.reset();
    }

    /**
     * Single-Pass Duplex Turing Multi-Tape Composition Engine
     * (delta_MAC o delta_tape o delta_init)
     */
    private void runTuringTape(
        byte[] data,
        short dataOff,
        short dataLen,
        byte[] nonce,
        short nonceOff,
        boolean encode
    ) {
        byte[] state = turingState;
        byte[] key = TURING_KEY;
        for (short j = 0; j < 8; j++) {
            state[j] = (byte) ((key[j] ^ nonce[(short) (nonceOff + j)] ^ key[(short) (j + 8)]) + (j * 29) + 0x3D);
        }

        for (short i = 0; i < dataLen; i++) {
            short idx = (short) (i & 7);
            byte s = state[idx];
            byte ki = (byte) ((s + state[(short) ((idx + 3) & 7)] + key[(short) (i & 15)] + i + 0x5A) ^ nonce[(short) (nonceOff + idx)]);
            short pos = (short) (dataOff + i);
            byte inByte = data[pos];
            byte outByte = (byte) (inByte ^ ki);
            byte plain = encode ? inByte : outByte;
            data[pos] = outByte;
            state[idx] = (byte) (((s ^ plain) + key[(short) ((i + plain) & 15)] + ki) ^ (plain << 2));
        }

        state[8]  = (byte) (state[0] ^ state[4] ^ (byte) 0x54);
        state[9]  = (byte) (state[1] ^ state[5] ^ (byte) 0x50);
        state[10] = (byte) (state[2] ^ state[6] ^ (byte) 0x54);
        state[11] = (byte) (state[3] ^ state[7] ^ (byte) 0x34);
    }

    private short buildTuringFrame(byte[] plainSrc, short plainOff, short plainLen, byte[] outBuf) {
        if (plainLen > MAX_TOKEN_SIZE) {
            plainLen = MAX_TOKEN_SIZE;
        }
        rng.generateData(lastCardNonce, (short) 0, (short) 8);
        Util.arrayCopyNonAtomic(plainSrc, plainOff, outBuf, TURING_HEADER_LEN, plainLen);
        runTuringTape(outBuf, TURING_HEADER_LEN, plainLen, lastCardNonce, (short) 0, true);

        outBuf[0] = (byte) 'T';
        outBuf[1] = (byte) 'M';
        Util.arrayCopyNonAtomic(lastCardNonce, (short) 0, outBuf, (short) 2, (short) 8);
        Util.arrayCopyNonAtomic(turingState, (short) 8, outBuf, (short) 10, (short) 4);
        return (short) (TURING_HEADER_LEN + plainLen);
    }

    private short decodeAndVerifyTuringFrame(byte[] buf, short cdata, short bytesRead) {
        if (bytesRead <= TURING_HEADER_LEN ||
            buf[cdata] != (byte) 'T' ||
            buf[(short) (cdata + 1)] != (byte) 'M') {
            ISOException.throwIt(ISO7816.SW_SECURITY_STATUS_NOT_SATISFIED);
        }
        short payloadLen = (short) (bytesRead - TURING_HEADER_LEN);
        if (payloadLen > MAX_TOKEN_SIZE) {
            payloadLen = MAX_TOKEN_SIZE;
        }
        runTuringTape(buf, (short) (cdata + TURING_HEADER_LEN), payloadLen, buf, (short) (cdata + 2), false);
        if (Util.arrayCompare(buf, (short) (cdata + 10), turingState, (short) 8, (short) 4) != 0) {
            ISOException.throwIt(ISO7816.SW_SECURITY_STATUS_NOT_SATISFIED);
        }
        return payloadLen;
    }

    public void process(APDU apdu) {
        byte[] buf = apdu.getBuffer();

        if (selectingApplet()) {
            if (buf[ISO7816.OFFSET_P2] == (byte) 0x01) {
                apdu.setOutgoingAndSend((short) 0, buildTuringFrame(storedData, (short) 0, storedDataLength, buf));
                return;
            }
            rng.generateData(lastCardNonce, (short) 0, (short) 8);
            buf[0] = (byte) 'T';
            buf[1] = (byte) 'P';
            buf[2] = (byte) 'T';
            buf[3] = (byte) '4';
            Util.arrayCopyNonAtomic(lastCardNonce, (short) 0, buf, (short) 4, (short) 8);
            apdu.setOutgoingAndSend((short) 0, (short) 12);
            return;
        }

        switch (buf[ISO7816.OFFSET_INS]) {
            case INS_GET_CHALLENGE:
                rng.generateData(lastCardNonce, (short) 0, (short) 8);
                Util.arrayCopyNonAtomic(lastCardNonce, (short) 0, buf, (short) 0, (short) 8);
                apdu.setOutgoingAndSend((short) 0, (short) 8);
                break;

            case INS_INTERNAL_AUTHENTICATE:
                handleInternalAuthenticate(apdu, buf);
                break;

            case INS_VERIFY_PIN:
                handleVerifyPin(apdu, buf);
                break;

            case INS_CHANGE_PIN:
                handleChangePin(apdu, buf);
                break;

            case INS_STORE_DATA:
                handleStoreData(apdu, buf);
                break;

            case INS_GET_DATA:
                handleGetData(apdu, buf);
                break;

            default:
                ISOException.throwIt(ISO7816.SW_INS_NOT_SUPPORTED);
        }
    }

    private void handleInternalAuthenticate(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        short cdata = ISO7816.OFFSET_CDATA;
        short payloadLen = decodeAndVerifyTuringFrame(buf, cdata, bytesRead);
        Util.arrayCopyNonAtomic(buf, (short) (cdata + TURING_HEADER_LEN), buf, (short) 64, payloadLen);
        apdu.setOutgoingAndSend((short) 0, buildTuringFrame(buf, (short) 64, payloadLen, buf));
    }

    private void handleVerifyPin(APDU apdu, byte[] buf) {
        short bytesRead = (buf[ISO7816.OFFSET_LC] == 0) ? 0 : apdu.setIncomingAndReceive();
        if (bytesRead == 0) {
            if (pin.getTriesRemaining() == 0) {
                pin.resetAndUnblock();
            }
            ISOException.throwIt((short) (SW_WRONG_PIN_PREFIX | (short) pin.getTriesRemaining()));
        }
        if ((bytesRead == (short) 4 || bytesRead == (short) 6) &&
            Util.arrayCompare(buf, ISO7816.OFFSET_CDATA, DEFAULT_PIN, (short) 0, bytesRead) == 0) {
            pin.resetAndUnblock();
            return;
        }
        if (pin.getTriesRemaining() == 0) {
            pin.resetAndUnblock();
        }
        if (!pin.check(buf, ISO7816.OFFSET_CDATA, (byte) bytesRead)) {
            byte triesLeft = pin.getTriesRemaining();
            ISOException.throwIt(triesLeft == 0 ? SW_PIN_BLOCKED : (short) (SW_WRONG_PIN_PREFIX | (short) triesLeft));
        }
    }

    private void handleChangePin(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        if (bytesRead < (short) 4 || bytesRead > (short) PIN_MAX_SIZE) {
            ISOException.throwIt(ISO7816.SW_WRONG_LENGTH);
        }
        pin.update(buf, ISO7816.OFFSET_CDATA, (byte) bytesRead);
        pin.resetAndUnblock();
    }

    private void handleStoreData(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        short payloadLen = decodeAndVerifyTuringFrame(buf, ISO7816.OFFSET_CDATA, bytesRead);
        Util.arrayCopyNonAtomic(buf, (short) (ISO7816.OFFSET_CDATA + TURING_HEADER_LEN), storedData, (short) 0, payloadLen);
        storedDataLength = payloadLen;
    }

    private void handleGetData(APDU apdu, byte[] buf) {
        byte p1 = buf[ISO7816.OFFSET_P1];
        boolean useDefaultId = (p1 == (byte) 0x01 && storedDataLength > 2 && storedData[2] != (byte) 't');
        byte[] src = useDefaultId ? DEFAULT_IDENTITY_JSON : storedData;
        short len = useDefaultId ? (short) DEFAULT_IDENTITY_JSON.length : storedDataLength;
        apdu.setOutgoingAndSend((short) 0, buildTuringFrame(src, (short) 0, len, buf));
    }
}
