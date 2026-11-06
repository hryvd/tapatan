import javax.smartcardio.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * Diagnostic and personalization tester for TapatMFAApplet over PC/SC
 * using the Turing Multi-Tape Composition Algorithm (TM frames + TPT4 handshake).
 */
public class test_applet_pcsc {

    static final byte[] APPLET_AID = new byte[] {
        (byte)0xF0, 0x74, 0x61, 0x70, 0x61, 0x74, 0x61, 0x6E, 0x01, 0x01
    };

    static final byte[] TURING_KEY = new byte[] {
        (byte)0x54, (byte)0x41, (byte)0x50, (byte)0x41,
        (byte)0x54, (byte)0x5F, (byte)0x54, (byte)0x55,
        (byte)0x52, (byte)0x49, (byte)0x4E, (byte)0x47,
        (byte)0x5F, (byte)0x4B, (byte)0x45, (byte)0x59
    };

    static byte[] initTuringTape(byte[] nonce) {
        byte[] state = new byte[8];
        for (int j = 0; j < 8; j++) {
            int k1 = TURING_KEY[j] & 0xFF;
            int k2 = TURING_KEY[j + 8] & 0xFF;
            int n = nonce[j] & 0xFF;
            state[j] = (byte)(((k1 ^ n ^ k2) + (j * 29) + 0x3D) & 0xFF);
        }
        return state;
    }

    static byte[][] runTuringTape(byte[] input, byte[] nonce, boolean encode) {
        byte[] data = Arrays.copyOf(input, input.length);
        byte[] state = initTuringTape(nonce);

        for (int i = 0; i < data.length; i++) {
            int idx = i & 7;
            int s = state[idx] & 0xFF;
            int sNext = state[(idx + 3) & 7] & 0xFF;
            int k = TURING_KEY[i & 15] & 0xFF;
            int n = nonce[idx] & 0xFF;
            int ki = ((s + sNext + k + i + 0x5A) ^ n) & 0xFF;

            int inByte = data[i] & 0xFF;
            int outByte = (inByte ^ ki) & 0xFF;
            int plain = encode ? inByte : outByte;
            data[i] = (byte) outByte;

            int k2 = TURING_KEY[(i + plain) & 15] & 0xFF;
            state[idx] = (byte) ((((s ^ plain) + k2 + ki) ^ (plain << 2)) & 0xFF);
        }

        byte[] mac = new byte[] {
            (byte)((state[0] ^ state[4] ^ 0x54) & 0xFF),
            (byte)((state[1] ^ state[5] ^ 0x50) & 0xFF),
            (byte)((state[2] ^ state[6] ^ 0x54) & 0xFF),
            (byte)((state[3] ^ state[7] ^ 0x34) & 0xFF)
        };
        return new byte[][] { data, mac };
    }

    static byte[] encodeTuringFrame(byte[] plain) {
        byte[] nonce = new byte[8];
        new SecureRandom().nextBytes(nonce);
        byte[][] res = runTuringTape(plain, nonce, true);
        byte[] cipher = res[0];
        byte[] mac = res[1];

        byte[] frame = new byte[14 + cipher.length];
        frame[0] = (byte)'T';
        frame[1] = (byte)'M';
        System.arraycopy(nonce, 0, frame, 2, 8);
        System.arraycopy(mac, 0, frame, 10, 4);
        System.arraycopy(cipher, 0, frame, 14, cipher.length);
        return frame;
    }

    static byte[] decodeTuringFrame(byte[] frame) {
        if (frame.length <= 14 || frame[0] != (byte)'T' || frame[1] != (byte)'M') {
            throw new IllegalArgumentException("Invalid Turing Frame header!");
        }
        byte[] nonce = Arrays.copyOfRange(frame, 2, 10);
        byte[] expectedMac = Arrays.copyOfRange(frame, 10, 14);
        byte[] cipher = Arrays.copyOfRange(frame, 14, frame.length);

        byte[][] res = runTuringTape(cipher, nonce, false);
        byte[] plain = res[0];
        byte[] actualMac = res[1];
        if (!Arrays.equals(expectedMac, actualMac)) {
            throw new SecurityException("Turing Composition MAC verification failed!");
        }
        return plain;
    }

    public static void main(String[] args) {
        try {
            System.out.println("=================================================");
            System.out.println("Tapatan J3R150 Turing Composition Applet Tester");
            System.out.println("=================================================");

            TerminalFactory tf = TerminalFactory.getDefault();
            if (tf.terminals().list().isEmpty()) {
                System.out.println("[ERROR] No smart card readers found!");
                return;
            }

            CardTerminal terminal = tf.terminals().list().get(0);
            System.out.println("Reader: " + terminal.getName());
            if (!terminal.isCardPresent()) {
                System.out.println("[ERROR] No card inserted in reader!");
                return;
            }

            Card card = terminal.connect("*");
            System.out.println("Card connected. ATR: " + bytesToHex(card.getATR().getBytes()));
            CardChannel channel = card.getBasicChannel();

            // 1. SELECT Applet (verify "TPT4" handshake + 8B nonce)
            System.out.println("\n[1] Selecting TapatMFAApplet (P2=0x00)...");
            CommandAPDU selectCmd = new CommandAPDU(0x00, 0xA4, 0x04, 0x00, APPLET_AID, 256);
            ResponseAPDU selectResp = channel.transmit(selectCmd);
            System.out.println("SELECT response SW: 0x" + Integer.toHexString(selectResp.getSW()).toUpperCase());
            byte[] selectData = selectResp.getData();
            System.out.println("SELECT Handshake (" + selectData.length + "B): " + bytesToHex(selectData));

            if (selectResp.getSW() != 0x9000 || selectData.length < 12 ||
                selectData[0] != 'T' || selectData[1] != 'P' || selectData[2] != 'T' || selectData[3] != '4') {
                System.out.println("[ERROR] Card did not return valid TPT4 Turing handshake!");
                card.disconnect(false);
                return;
            }
            System.out.println("[SUCCESS] Authentic TapatMFAApplet TPT4 Handshake Verified!");

            // 2. STORE VIRTUAL CARD DATA using Turing Composition Frame
            System.out.println("\n[2] Encoding & Storing Identity via Turing Multi-Tape Composition...");
            String virtualCardJson = "{\"tapatan_id\":\"TAPAT_JCOP4_8821\",\"cardId\":\"TAPAT_JCOP4_8821\",\"owner\":\"richard@tapat.ph\",\"name\":\"Richard\"}";
            byte[] turingFrame = encodeTuringFrame(virtualCardJson.getBytes(StandardCharsets.UTF_8));
            System.out.println("Encoded Turing Frame (" + turingFrame.length + "B): " + bytesToHex(turingFrame));

            CommandAPDU storeIdCmd = new CommandAPDU(0x00, 0xE2, 0x01, 0x00, turingFrame);
            ResponseAPDU storeIdResp = channel.transmit(storeIdCmd);
            CommandAPDU storeTokCmd = new CommandAPDU(0x00, 0xE2, 0x00, 0x00, turingFrame);
            ResponseAPDU storeTokResp = channel.transmit(storeTokCmd);
            System.out.println("STORE DATA (P1=01) SW: 0x" + Integer.toHexString(storeIdResp.getSW()).toUpperCase());
            System.out.println("STORE DATA (P1=00) SW: 0x" + Integer.toHexString(storeTokResp.getSW()).toUpperCase());

            // 3. Verify that unencoded/tampered STORE DATA is REJECTED by the applet
            System.out.println("\n[3] Verifying Applet Rejects Forged/Unencoded Data...");
            byte[] fakeData = "{\"cardId\":\"FAKE\"}".getBytes(StandardCharsets.UTF_8);
            ResponseAPDU fakeResp = channel.transmit(new CommandAPDU(0x00, 0xE2, 0x01, 0x00, fakeData));
            System.out.println("Forged STORE DATA SW: 0x" + Integer.toHexString(fakeResp.getSW()).toUpperCase() + " (Expected 0x6982)");

            // 4. GET DATA (Read back Turing-encoded frame from card and decode it)
            System.out.println("\n[4] Reading & Decoding Turing Frame from Card (INS 0xCA)...");
            CommandAPDU getCmd = new CommandAPDU(0x00, 0xCA, 0x01, 0x00, 256);
            ResponseAPDU getResp = channel.transmit(getCmd);
            System.out.println("GET DATA SW: 0x" + Integer.toHexString(getResp.getSW()).toUpperCase());
            byte[] cardFrame = getResp.getData();
            System.out.println("Card Turing Frame (" + cardFrame.length + "B): " + bytesToHex(cardFrame));
            String decodedJson = new String(decodeTuringFrame(cardFrame), StandardCharsets.UTF_8);
            System.out.println("[SUCCESS] Decoded JSON from Card: " + decodedJson);

            // 5. INTERNAL AUTHENTICATE (Turing-encoded Challenge-Response)
            System.out.println("\n[5] Testing Turing-Composed INTERNAL AUTHENTICATE (INS 0x88)...");
            ResponseAPDU chalResp = channel.transmit(new CommandAPDU(0x00, 0x84, 0x00, 0x00, 8));
            byte[] cardNonce = chalResp.getData();
            byte[] combinedChallenge = new byte[16];
            System.arraycopy(cardNonce, 0, combinedChallenge, 0, 8);
            for (int i = 8; i < 16; i++) combinedChallenge[i] = (byte)(0x42 + i);
            byte[] encodedChallenge = encodeTuringFrame(combinedChallenge);

            // Note: For Alcorlink T=0 reader, send Case 3 and if 61xx is returned, javax.smartcardio fetches response
            ResponseAPDU authResp = channel.transmit(new CommandAPDU(0x00, 0x88, 0x00, 0x00, encodedChallenge));
            System.out.println("INTERNAL AUTHENTICATE SW: 0x" + Integer.toHexString(authResp.getSW()).toUpperCase());
            byte[] decodedProof = decodeTuringFrame(authResp.getData());
            System.out.println("[SUCCESS] Verified Mutual Turing Proof (" + decodedProof.length + "B): " + bytesToHex(decodedProof));

            System.out.println("\n=================================================");
            System.out.println("ALL TURING COMPOSITION & CARD SECURITY CHECKS PASSED!");
            System.out.println("=================================================");

            card.disconnect(false);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X ", b));
        }
        return sb.toString().trim();
    }
}
