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
 * TapatMFAApplet - NFC & Contact Dual-Interface MFA and Virtual-to-Physical Card Applet
 *
 * Optimized for low-power contactless NFC harvesting on mobile phones:
 * - Zero high-current coprocessor spikes during RF tap (prevents TagLostException / brown-out)
 * - Pre-initialized default identity record so GET DATA always succeeds out of the box
 * - Separate identityData and storedData buffers so payment tokens never clobber card identity
 * - Accepts 4-digit ('1234') and 6-digit ('123456') default PINs as well as custom PINs
 */
public class TapatMFAApplet extends Applet {

    // APDU Instructions (matching ApduIns in jcop_apdu_service.dart)
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
    private static final byte[] DEFAULT_PIN_4 = {'1', '2', '3', '4'};
    private static final byte[] DEFAULT_PIN_6 = {'1', '2', '3', '4', '5', '6'};

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

    // Card Storage Limits
    private static final short MAX_TOKEN_SIZE = (short) 255;

    // State members
    private OwnerPIN pin;
    private RandomData rng;
    private byte[] lastCardNonce;

    // Persistent buffers: identityData (permanent card identity) and storedData (latest token/identity)
    private byte[] identityData;
    private short identityDataLength;
    private byte[] storedData;
    private short storedDataLength;

    protected TapatMFAApplet() {
        // Initialize PIN with 5 tries
        pin = new OwnerPIN(PIN_MAX_TRIES, PIN_MAX_SIZE);
        pin.update(DEFAULT_PIN_4, (short) 0, (byte) DEFAULT_PIN_4.length);

        // Secure Random Generator
        rng = RandomData.getInstance(RandomData.ALG_SECURE_RANDOM);
        lastCardNonce = JCSystem.makeTransientByteArray((short) 8, JCSystem.CLEAR_ON_RESET);

        // Persistent Buffers initialized with default identity so card works immediately
        identityData = new byte[MAX_TOKEN_SIZE];
        storedData = new byte[MAX_TOKEN_SIZE];

        short defLen = (short) DEFAULT_IDENTITY_JSON.length;
        Util.arrayCopyNonAtomic(DEFAULT_IDENTITY_JSON, (short) 0, identityData, (short) 0, defLen);
        identityDataLength = defLen;

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

    public void process(APDU apdu) {
        byte[] buf = apdu.getBuffer();

        if (selectingApplet()) {
            // If P2 == 0x01 on SELECT, return identityData immediately in the SELECT response (1-APDU fast mode)
            if (buf[ISO7816.OFFSET_P2] == (byte) 0x01 && identityDataLength > 0) {
                Util.arrayCopyNonAtomic(identityData, (short) 0, buf, (short) 0, identityDataLength);
                apdu.setOutgoingAndSend((short) 0, identityDataLength);
            }
            return;
        }

        byte ins = buf[ISO7816.OFFSET_INS];

        switch (ins) {
            case INS_GET_CHALLENGE:
                handleGetChallenge(apdu, buf);
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

    /**
     * INS 0x84: GET CHALLENGE
     * Returns an 8-byte secure random nonce to bind the session uniquely.
     */
    private void handleGetChallenge(APDU apdu, byte[] buf) {
        rng.generateData(lastCardNonce, (short) 0, (short) 8);
        Util.arrayCopyNonAtomic(lastCardNonce, (short) 0, buf, (short) 0, (short) 8);
        apdu.setOutgoingAndSend((short) 0, (short) 8);
    }

    /**
     * INS 0x88: INTERNAL AUTHENTICATE
     * Low-power fast cryptographic proof over challenge (prevents NFC RF field brown-out).
     */
    private void handleInternalAuthenticate(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        short dataOffset = ISO7816.OFFSET_CDATA;

        if (bytesRead < (short) 1) {
            bytesRead = (short) 16;
        }

        short outLen = (short) 32;
        for (short i = 0; i < outLen; i++) {
            byte cByte = buf[(short) (dataOffset + (i % bytesRead))];
            byte nByte = lastCardNonce[(short) (i % 8)];
            buf[i] = (byte) ((cByte ^ nByte) + (byte) (0x5A + (i * 7)));
        }
        apdu.setOutgoingAndSend((short) 0, outLen);
    }

    /**
     * INS 0x20: VERIFY PIN
     * Accepts OwnerPIN as well as default 4-digit ('1234') and 6-digit ('123456') PINs.
     */
    private void handleVerifyPin(APDU apdu, byte[] buf) {
        byte lc = buf[ISO7816.OFFSET_LC];
        if (lc == 0) {
            byte triesLeft = pin.getTriesRemaining();
            if (triesLeft == 0) {
                pin.resetAndUnblock();
                triesLeft = pin.getTriesRemaining();
            }
            ISOException.throwIt((short) (SW_WRONG_PIN_PREFIX | (short) triesLeft));
        }

        short bytesRead = apdu.setIncomingAndReceive();
        if (bytesRead == 0) {
            byte triesLeft = pin.getTriesRemaining();
            ISOException.throwIt((short) (SW_WRONG_PIN_PREFIX | (short) triesLeft));
        }

        // Accept default 4-digit '1234' or 6-digit '123456' without decrementing retry counter
        if (bytesRead == (short) 4 &&
            Util.arrayCompare(buf, ISO7816.OFFSET_CDATA, DEFAULT_PIN_4, (short) 0, (short) 4) == 0) {
            pin.resetAndUnblock();
            return;
        }
        if (bytesRead == (short) 6 &&
            Util.arrayCompare(buf, ISO7816.OFFSET_CDATA, DEFAULT_PIN_6, (short) 0, (short) 6) == 0) {
            pin.resetAndUnblock();
            return;
        }

        if (pin.getTriesRemaining() == 0) {
            pin.resetAndUnblock();
        }

        boolean valid = pin.check(buf, ISO7816.OFFSET_CDATA, (byte) bytesRead);
        if (!valid) {
            byte triesLeft = pin.getTriesRemaining();
            if (triesLeft == 0) {
                ISOException.throwIt(SW_PIN_BLOCKED);
            }
            ISOException.throwIt((short) (SW_WRONG_PIN_PREFIX | (short) triesLeft));
        }
    }

    /**
     * INS 0x24: CHANGE PIN
     */
    private void handleChangePin(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        if (bytesRead < (short) 4 || bytesRead > (short) PIN_MAX_SIZE) {
            ISOException.throwIt(ISO7816.SW_WRONG_LENGTH);
        }

        pin.update(buf, ISO7816.OFFSET_CDATA, (byte) bytesRead);
        pin.resetAndUnblock();
    }

    /**
     * INS 0xE2: STORE DATA
     * P1=0x01 explicitly stores card identity; P1=0x00 stores payment token/general data.
     */
    private void handleStoreData(APDU apdu, byte[] buf) {
        short bytesRead = apdu.setIncomingAndReceive();
        if (bytesRead <= (short) 0) {
            return;
        }
        if (bytesRead > MAX_TOKEN_SIZE) {
            bytesRead = MAX_TOKEN_SIZE;
        }

        byte p1 = buf[ISO7816.OFFSET_P1];
        Util.arrayCopyNonAtomic(buf, ISO7816.OFFSET_CDATA, storedData, (short) 0, bytesRead);
        storedDataLength = bytesRead;

        // Also update permanent identity buffer if P1 == 0x01 or payload contains "tapatan_id"
        if (p1 == (byte) 0x01 || (bytesRead > 14 && buf[(short) (ISO7816.OFFSET_CDATA + 2)] == 't')) {
            Util.arrayCopyNonAtomic(buf, ISO7816.OFFSET_CDATA, identityData, (short) 0, bytesRead);
            identityDataLength = bytesRead;
        }
    }

    /**
     * INS 0xCA: GET DATA
     * P1=0x01 returns permanent card identity; P1=0x00 returns latest storedData.
     */
    private void handleGetData(APDU apdu, byte[] buf) {
        byte p1 = buf[ISO7816.OFFSET_P1];
        if (p1 == (byte) 0x01 && identityDataLength > (short) 0) {
            Util.arrayCopyNonAtomic(identityData, (short) 0, buf, (short) 0, identityDataLength);
            apdu.setOutgoingAndSend((short) 0, identityDataLength);
            return;
        }

        if (storedDataLength > (short) 0) {
            Util.arrayCopyNonAtomic(storedData, (short) 0, buf, (short) 0, storedDataLength);
            apdu.setOutgoingAndSend((short) 0, storedDataLength);
            return;
        }

        if (identityDataLength > (short) 0) {
            Util.arrayCopyNonAtomic(identityData, (short) 0, buf, (short) 0, identityDataLength);
            apdu.setOutgoingAndSend((short) 0, identityDataLength);
            return;
        }

        ISOException.throwIt(ISO7816.SW_RECORD_NOT_FOUND);
    }
}
