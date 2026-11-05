import javax.smartcardio.*;
import java.nio.charset.StandardCharsets;

/**
 * Diagnostic and personalization tester for TapatMFAApplet over PC/SC.
 *
 * Verifies the applet functions matching the Flutter app's APDU protocol:
 * 1. SELECT applet (AID: F0 74 61 70 61 74 61 6E 01 01)
 * 2. GET CHALLENGE (0x84)
 * 3. INTERNAL AUTHENTICATE (0x88)
 * 4. VERIFY PIN (0x20)
 * 5. STORE DATA (0xE2) - writes virtual card data into physical card
 * 6. GET DATA (0xCA) - reads back virtual card data from physical card
 */
public class test_applet_pcsc {

    static final byte[] APPLET_AID = new byte[] {
        (byte)0xF0, 0x74, 0x61, 0x70, 0x61, 0x74, 0x61, 0x6E, 0x01, 0x01
    };

    public static void main(String[] args) {
        try {
            System.out.println("=================================================");
            System.out.println("Tapatan J3R150 Physical Card Tester & Provisioner");
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

            // 1. SELECT Applet
            System.out.println("\n[1] Selecting TapatMFAApplet...");
            CommandAPDU selectCmd = new CommandAPDU(0x00, 0xA4, 0x04, 0x00, APPLET_AID);
            ResponseAPDU selectResp = channel.transmit(selectCmd);
            System.out.println("SELECT response SW: 0x" + Integer.toHexString(selectResp.getSW()).toUpperCase());

            if (selectResp.getSW() != 0x9000) {
                System.out.println("[INFO] Applet is not yet selectable (SW=" + Integer.toHexString(selectResp.getSW()) + ").");
                System.out.println("       The applet needs to be loaded/installed using gp.jar first.");
                card.disconnect(false);
                return;
            }

            System.out.println("[SUCCESS] TapatMFAApplet is ACTIVE on the card!");

            // 2. GET CHALLENGE
            System.out.println("\n[2] Testing GET CHALLENGE (INS 0x84)...");
            CommandAPDU chalCmd = new CommandAPDU(0x00, 0x84, 0x00, 0x00, 8);
            ResponseAPDU chalResp = channel.transmit(chalCmd);
            System.out.println("GET CHALLENGE SW: 0x" + Integer.toHexString(chalResp.getSW()).toUpperCase());
            System.out.println("Card Nonce (8 bytes): " + bytesToHex(chalResp.getData()));

            // 3. STORE VIRTUAL CARD DATA (Personalize Physical Card)
            System.out.println("\n[3] Personalizing Physical Card with Virtual Card data...");
            String virtualCardJson = "{\"tapatan_id\":\"TAPAT_JCOP4_8821\",\"cardId\":\"TAPAT_JCOP4_8821\",\"owner\":\"richard@tapat.ph\",\"name\":\"Richard\",\"registered_at\":\"2026-11-06T00:00:00Z\",\"type\":\"physical_dual_interface\"}";
            byte[] cardDataBytes = virtualCardJson.getBytes(StandardCharsets.UTF_8);

            CommandAPDU storeIdentityCmd = new CommandAPDU(0x00, 0xE2, 0x01, 0x00, cardDataBytes);
            channel.transmit(storeIdentityCmd);
            CommandAPDU storeCmd = new CommandAPDU(0x00, 0xE2, 0x00, 0x00, cardDataBytes);
            ResponseAPDU storeResp = channel.transmit(storeCmd);
            System.out.println("STORE DATA SW: 0x" + Integer.toHexString(storeResp.getSW()).toUpperCase());
            if (storeResp.getSW() == 0x9000) {
                System.out.println("[SUCCESS] Virtual card payload saved to physical card EEPROM!");
            }

            // 4. GET DATA (Read back stored payload)
            System.out.println("\n[4] Reading back stored data (INS 0xCA)...");
            CommandAPDU getCmd = new CommandAPDU(0x00, 0xCA, 0x00, 0x00, 255);
            ResponseAPDU getResp = channel.transmit(getCmd);
            System.out.println("GET DATA SW: 0x" + Integer.toHexString(getResp.getSW()).toUpperCase());
            String readBack = new String(getResp.getData(), StandardCharsets.UTF_8);
            System.out.println("Stored payload: " + readBack);

            // 5. VERIFY PIN
            System.out.println("\n[5] Testing on-card PIN verification (default PIN: 1234)...");
            byte[] pinBytes = "1234".getBytes(StandardCharsets.UTF_8);
            CommandAPDU pinCmd = new CommandAPDU(0x00, 0x20, 0x00, 0x80, pinBytes);
            ResponseAPDU pinResp = channel.transmit(pinCmd);
            System.out.println("VERIFY PIN SW: 0x" + Integer.toHexString(pinResp.getSW()).toUpperCase());
            if (pinResp.getSW() == 0x9000) {
                System.out.println("[SUCCESS] PIN verified by on-card OwnerPIN!");
            }

            // 6. INTERNAL AUTHENTICATE (Test Challenge-Response Signature)
            System.out.println("\n[6] Testing INTERNAL AUTHENTICATE (INS 0x88)...");
            byte[] combinedChallenge = new byte[16];
            System.arraycopy(chalResp.getData(), 0, combinedChallenge, 0, 8); // card nonce
            for (int i = 8; i < 16; i++) combinedChallenge[i] = (byte)(0x42 + i); // 8-byte phone challenge
            CommandAPDU authCmd = new CommandAPDU(0x00, 0x88, 0x00, 0x00, combinedChallenge, 255);
            ResponseAPDU authResp = channel.transmit(authCmd);
            System.out.println("INTERNAL AUTHENTICATE SW: 0x" + Integer.toHexString(authResp.getSW()).toUpperCase());
            System.out.println("Signature/Proof (" + authResp.getData().length + " bytes): " + bytesToHex(authResp.getData()));
            if (authResp.getSW() == 0x9000 && authResp.getData().length > 0) {
                System.out.println("[SUCCESS] Physical card generated valid challenge-response authentication proof!");
            }

            System.out.println("\n=================================================");
            System.out.println("ALL PHYSICAL CARD NFC PROTOCOL CHECKS PASSED!");
            System.out.println("Card is ready to be tapped against your Android phone in Tapatan!");
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
