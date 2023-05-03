--
-- XXDO_CHECK_PRINT_SIGN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_CHECK_PRINT_SIGN_PKG"
AS
    -- =======================================================================================
    -- NAME: XXDO_CHECK_PRINT_SIGN_PKG.pkb
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Body
    -- PURPOSE:
    -- While printing check in PPR, Fetch the signature from database which
    --                is encrypted and decrypted
    -- NOTES
    --
    --
    -- HISTORY
    -- =======================================================================================
    --  Date          Author                                Version             Activity
    -- =======================================================================================
    --
    -- 2-May-2015    BTDev team                             1.0             Initial Version
    -- 12-Apr-2016      BTDev team                                      1.1                    Commented fnd_file.output from proc    printmessage
    --
    -- =======================================================================================
    PROCEDURE printmessage (p_msgtoken IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msgtoken);
        --Start commenting on 12-Apr-2016 by BTDEV Team for Smoke Test issue HSBC Payment output had extra characters
        -- fnd_file.put_line (fnd_file.output, p_msgtoken);
        --End commenting on 12-Apr-2016 by BTDEV Team for Smoke Test issue HSBC Payment output had extra characters
        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error in printMessage');
    END printmessage;

    PROCEDURE loadsignature256bit (p_xerrmsg OUT NOCOPY VARCHAR2, p_xerrcode OUT NOCOPY NUMBER, p_signaturename IN VARCHAR2
                                   , p_signaturelocation IN VARCHAR2)
    IS
        lf_lob                      BFILE;
        lb_lob                      BLOB;
        lb_encryptedblob            BLOB;
        aes256_cbc_pkcs5   CONSTANT PLS_INTEGER
            :=   DBMS_CRYPTO.encrypt_aes256
               + DBMS_CRYPTO.chain_cbc
               + DBMS_CRYPTO.pad_pkcs5 ;
    BEGIN
        p_xerrcode   := 0;
        p_xerrmsg    := NULL;

        BEGIN
            DELETE FROM xxdo_iby_check_sign_tbl
                  WHERE INSTR (blob_id, p_signaturename) >= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while deleting data from XXDO_IBY_CHECK_SIGN_TBL table - '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_iby_check_sign_tbl
                 VALUES (p_signaturename, EMPTY_BLOB ())
                 RETURN blob_val
                   INTO lb_encryptedblob;

            INSERT INTO xxdo_iby_check_sign_tbl
                 VALUES (p_signaturename || '- TEMP', EMPTY_BLOB ())
                 RETURN blob_val
                   INTO lb_lob;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while inserting into XXDO_IBY_CHECK_SIGN_TBL table - '
                    || SQLERRM);
        END;

        BEGIN
            lf_lob   := BFILENAME (p_signaturelocation, p_signaturename);
            DBMS_LOB.fileopen (lf_lob, DBMS_LOB.file_readonly);
            DBMS_LOB.loadfromfile (lb_lob,
                                   lf_lob,
                                   DBMS_LOB.getlength (lf_lob));
            DBMS_LOB.fileclose (lf_lob);
            printmessage (
                '1: lb_encryptedBlob: ' || DBMS_LOB.getlength (lb_encryptedblob));
            printmessage ('1: lb_lob: ' || DBMS_LOB.getlength (lb_lob));
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while reading file from server - '
                    || SQLERRM);
        END;

        DBMS_OUTPUT.put_line (
            '1: lb_encryptedBlob: ' || DBMS_LOB.getlength (lb_encryptedblob));
        DBMS_OUTPUT.put_line ('1: lb_lob: ' || DBMS_LOB.getlength (lb_lob));

        BEGIN
            DBMS_CRYPTO.encrypt (
                dst   => lb_encryptedblob,
                src   => lb_lob,
                typ   => aes256_cbc_pkcs5,
                KEY   =>
                    HEXTORAW (
                        '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F'),
                iv    => HEXTORAW ('00000000000000000000000000000000'));
        EXCEPTION
            WHEN OTHERS
            THEN
                printmessage ('ENCRYPT - SQLERRM: ' || SQLERRM);
        END;

        printmessage (
            '2: lb_encryptedBlob: ' || DBMS_LOB.getlength (lb_encryptedblob));
        printmessage ('2: lb_lob: ' || DBMS_LOB.getlength (lb_lob));

        DBMS_OUTPUT.put_line (
            '2: lb_encryptedBlob: ' || DBMS_LOB.getlength (lb_encryptedblob));
        DBMS_OUTPUT.put_line ('2: lb_lob: ' || DBMS_LOB.getlength (lb_lob));

        BEGIN
            UPDATE xxdo_iby_check_sign_tbl
               SET blob_val   = EMPTY_BLOB ()
             WHERE blob_id = p_signaturename || '- TEMP';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while updating XXDO_IBY_CHECK_SIGN_TBL - '
                    || SQLERRM);
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_xerrcode   := 1;
            p_xerrmsg    := 'Unable to Load Signature - ' || SQLERRM;
    END loadsignature256bit;

    PROCEDURE fetchsignature256bit (p_clob            IN OUT CLOB,
                                    p_signaturename          VARCHAR)
    IS
        lc_signature                CLOB;
        lb_signature                BLOB;
        lb_decryptedblob            BLOB;
        aes256_cbc_pkcs5   CONSTANT PLS_INTEGER
            :=   DBMS_CRYPTO.encrypt_aes256
               + DBMS_CRYPTO.chain_cbc
               + DBMS_CRYPTO.pad_pkcs5 ;
        -- below added by pradeep
        lc_org_name                 hr_all_organization_units.NAME%TYPE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    -- Added by MC23876 Dated 07/20/2009 for R12 upgrade
    BEGIN
        --FND_FILE.PUT_LINE(FND_FILE.LOG,'Step1 ');
        /*SELECT NAME
          INTO lc_org_name
          FROM hr_all_organization_units
         WHERE organization_id = mo_global.get_current_org_id; */
        --FND_FILE.PUT_LINE(FND_FILE.LOG,'Step2 ');
        BEGIN
            SELECT blob_val
              INTO lb_signature
              FROM xxdo_iby_check_sign_tbl
             WHERE blob_id = p_signaturename;       --default_check_signature;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while fetching lb_signature - '
                    || SQLERRM);
        END;

        --FND_FILE.PUT_LINE(FND_FILE.LOG,'Step3 ');
        -- above added by pradeep
        BEGIN
            SELECT blob_val
              INTO lb_decryptedblob
              FROM xxdo_iby_check_sign_tbl
             WHERE 1 = 1 AND INSTR (blob_id, 'TEMP') >= 1 AND ROWNUM < 2
            FOR UPDATE;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception raised while fetching data from XXDO_IBY_CHECK_SIGN_TBL table - '
                    || SQLERRM);
        END;

        --FND_FILE.PUT_LINE(FND_FILE.LOG,'Step4 ');
        printmessage (
            '3: lb_decryptedBlob: ' || DBMS_LOB.getlength (lb_decryptedblob));
        printmessage (
            '3: lb_signature: ' || DBMS_LOB.getlength (lb_signature));

        BEGIN
            DBMS_CRYPTO.decrypt (
                dst   => lb_decryptedblob,
                src   => lb_signature,
                typ   => aes256_cbc_pkcs5,
                KEY   =>
                    HEXTORAW (
                        '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F'),
                iv    => HEXTORAW ('00000000000000000000000000000000'));
        EXCEPTION
            WHEN OTHERS
            THEN
                printmessage ('DECRYPT - SQLERRM: ' || SQLERRM);
        END;

        --FND_FILE.PUT_LINE(FND_FILE.LOG,'Step5 ');
        printmessage (
            '4: lb_decryptedBlob: ' || DBMS_LOB.getlength (lb_decryptedblob));
        printmessage (
            '4: lb_signature: ' || DBMS_LOB.getlength (lb_signature));
        DBMS_LOB.createtemporary (lc_signature, FALSE, 0);
        wf_mail_util.encodeblob (lb_decryptedblob, lc_signature);

        BEGIN
            UPDATE xxdo_iby_check_sign_tbl
               SET blob_val   = EMPTY_BLOB ()
             WHERE INSTR (blob_id, 'TEMP') >= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;
        p_clob   := lc_signature;
    EXCEPTION
        WHEN OTHERS
        THEN
            printmessage ('fetchSignature256Bit - SqlErrm: ' || SQLERRM);
    END fetchsignature256bit;
END xxdo_check_print_sign_pkg;
/
