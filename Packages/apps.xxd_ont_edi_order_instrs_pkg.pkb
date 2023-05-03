--
-- XXD_ONT_EDI_ORDER_INSTRS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_EDI_ORDER_INSTRS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_EDI_ORDER_INSTRS_PKG
    * Design       : This package is used for creating/attaching shipping/packing/pick ticket
    *                Instructions for EDI Orders
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    -- 23-Sep-2019  1.1        Aravind Kannuri         Changes as per CCR0008045
    -- 21-Sep-2020  1.2        Viswanathan Pandian     Updated for CCR0008488
    ******************************************************************************************/
    -- Start changes for CCR0008488
    PROCEDURE update_osdr
    AS
        CURSOR get_osdr (p_account_number IN VARCHAR2, p_cust_po_number IN VARCHAR2, p_global_attribute1 IN VARCHAR2)
        IS
            SELECT ooha.orig_sys_document_ref osdr
              FROM oe_order_headers_all ooha, hz_cust_accounts hca
             WHERE     ooha.sold_to_org_id = hca.cust_account_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = fnd_global.org_id
                   AND ooha.cust_po_number = p_cust_po_number
                   AND hca.account_number = p_account_number
                   AND ((p_global_attribute1 = 'BK' AND ooha.global_attribute1 = p_global_attribute1) OR (p_global_attribute1 <> 'BK' AND NVL (ooha.global_attribute1, p_global_attribute1) = p_global_attribute1) OR (NVL (p_global_attribute1, 'X') = NVL (NVL (ooha.global_attribute1, p_global_attribute1), 'X')));

        lc_osdr        VARCHAR2 (50);
        lcu_osdr_rec   get_osdr%ROWTYPE;
    BEGIN
        FOR inst_rec
            IN (SELECT instruction_id, account_number, cust_po_number,
                       global_attribute1
                  FROM xxd_ont_edi_order_instrs_t
                 WHERE     orig_sys_document_ref IS NULL
                       AND operation_mode = 'UPDATE (860)'
                       AND account_number IS NOT NULL
                       AND status = 'N')
        LOOP
            lc_osdr   := NULL;
            fnd_file.put_line (fnd_file.LOG, (RPAD ('=', 100, '=')));
            fnd_file.put_line (
                fnd_file.LOG,
                'Processing for Instruction ID = ' || inst_rec.instruction_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'Account Number = ' || inst_rec.account_number);
            fnd_file.put_line (
                fnd_file.LOG,
                'Cust PO Number = ' || inst_rec.cust_po_number);
            fnd_file.put_line (
                fnd_file.LOG,
                'Gloabl Attribute1 = ' || inst_rec.global_attribute1);

            OPEN get_osdr (inst_rec.account_number,
                           inst_rec.cust_po_number,
                           inst_rec.global_attribute1);

           <<osdr>>
            LOOP
                FETCH get_osdr INTO lcu_osdr_rec;

                IF get_osdr%ROWCOUNT = 1
                THEN
                    lc_osdr   := lcu_osdr_rec.osdr;
                    fnd_file.put_line (fnd_file.LOG, 'OSDR = ' || lc_osdr);
                ELSIF get_osdr%ROWCOUNT = 0
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'No data found');
                    lc_osdr   := NULL;
                ELSIF get_osdr%ROWCOUNT > 1
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'More than one record found. Count = '
                        || get_osdr%ROWCOUNT);
                    lc_osdr   := NULL;
                END IF;

                EXIT osdr WHEN get_osdr%NOTFOUND;
            END LOOP;

            CLOSE get_osdr;

            IF lc_osdr IS NOT NULL
            THEN
                UPDATE xxd_ont_edi_order_instrs_t xooh
                   SET orig_sys_document_ref   = lc_osdr
                 WHERE instruction_id = inst_rec.instruction_id;

                fnd_file.put_line (fnd_file.LOG,
                                   'Updated OSDR. Count = ' || SQL%ROWCOUNT);
            END IF;

            fnd_file.put_line (fnd_file.LOG, (RPAD ('=', 100, '=')));
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPDATE_OSDR - ' || SQLERRM);
    END update_osdr;

    -- End changes for CCR0008488

    PROCEDURE create_attach_documents (
        x_errbuf                     OUT NOCOPY VARCHAR2,
        x_retcode                    OUT NOCOPY VARCHAR2,
        p_org_id                  IN            oe_order_headers_all.org_id%TYPE,
        p_orig_sys_document_ref   IN            oe_order_headers_all.orig_sys_document_ref%TYPE)
    AS
        CURSOR get_data IS
            SELECT xoeo.instruction_id, ooha.header_id, xoeo.orig_sys_document_ref,
                   xoeo.file_name, xoeo.file_data, LENGTH (xoeo.file_data) file_length,
                   fdcv.user_name, fdcv.category_id, SUBSTR (REPLACE (REPLACE (xoeo.file_name, '.txt', ''), xoeo.orig_sys_document_ref, ''), 2, LENGTH (xoeo.orig_sys_document_ref)) title
              FROM xxd_ont_edi_order_instrs_t xoeo, oe_order_headers_all ooha, fnd_document_categories_vl fdcv
             WHERE     xoeo.orig_sys_document_ref =
                       ooha.orig_sys_document_ref
                   AND xoeo.org_id = ooha.org_id
                   AND xoeo.instruction_category = fdcv.user_name
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_headers_iface_all ohia
                             WHERE     xoeo.orig_sys_document_ref =
                                       ohia.orig_sys_document_ref
                                   AND xoeo.org_id = ohia.org_id
                                   AND NVL (ohia.error_flag, 'N') = 'Y')
                   AND xoeo.org_id = p_org_id
                   AND xoeo.orig_sys_document_ref =
                       NVL (p_orig_sys_document_ref,
                            xoeo.orig_sys_document_ref)
                   AND xoeo.status = 'N';

        ln_rowid                  ROWID;
        ln_attached_document_id   NUMBER;
        ln_document_id            NUMBER;
        ln_media_id               NUMBER;
        ln_seq_num                NUMBER;
        ln_short_datatype_id      NUMBER;
        lc_status                 VARCHAR2 (1) := 'S';
        lc_error_message          VARCHAR2 (4000);
    BEGIN
        -- Start changes for CCR0008488
        update_osdr;

        -- End changes for CCR0008488

        -- Get Data type id for Short Text types of attachments
        SELECT datatype_id
          INTO ln_short_datatype_id
          FROM fnd_document_datatypes
         WHERE name = 'FILE' AND language = USERENV ('LANG');

        FOR lcu_data IN get_data
        LOOP
            IF lcu_data.file_length > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Start Processing for Category '
                    || lcu_data.user_name
                    || ' for '
                    || lcu_data.orig_sys_document_ref);

                SELECT fnd_lobs_s.NEXTVAL INTO ln_media_id FROM DUAL;

                SAVEPOINT before_document;

                BEGIN
                    -- Insert a new record into the table containing the
                    INSERT INTO fnd_lobs (file_id, file_name, file_content_type, upload_date, expiration_date, program_name, program_tag, file_data, language
                                          , oracle_charset, file_format)
                         VALUES (ln_media_id, lcu_data.file_name, 'text/plain', SYSDATE, NULL, 'FNDATTCH', NULL, lcu_data.file_data, USERENV ('LANG')
                                 , 'UTF8', 'text');

                    fnd_file.put_line (fnd_file.LOG,
                                       'Created LOB File ' || ln_media_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_status   := 'E';
                        lc_error_message   :=
                            'Lobs Exception - ' || SUBSTR (SQLERRM, 1, 3950);
                        ROLLBACK TO before_document;
                END;

                IF lc_status <> 'E'
                THEN
                    BEGIN
                        -- Select nexvalues of document id, attached document id
                        SELECT fnd_documents_s.NEXTVAL, fnd_attached_documents_s.NEXTVAL
                          INTO ln_document_id, ln_attached_document_id
                          FROM DUAL;

                        -- Document Creation
                        fnd_documents_pkg.insert_row (
                            x_rowid               => ln_rowid,
                            x_document_id         => ln_document_id,
                            x_creation_date       => SYSDATE,
                            x_created_by          => gn_user_id,
                            x_last_update_date    => SYSDATE,
                            x_last_updated_by     => gn_user_id,
                            x_last_update_login   => gn_login_id,
                            x_datatype_id         => ln_short_datatype_id,
                            x_security_id         => NULL,
                            x_publish_flag        => 'Y',
                            x_category_id         => lcu_data.category_id,
                            x_security_type       => 4,
                            x_usage_type          => 'O',
                            x_language            => USERENV ('LANG'),
                            x_description         => lcu_data.file_name,
                            x_file_name           => lcu_data.file_name,
                            x_media_id            => ln_media_id,
                            x_title               => lcu_data.title);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Created Document ' || ln_document_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_status   := 'E';
                            lc_error_message   :=
                                   'Document Exception - '
                                || SUBSTR (SQLERRM, 1, 3950);
                            ROLLBACK TO before_document;
                    END;

                    IF lc_status <> 'E'
                    THEN
                        BEGIN
                            -- Select next Sequence of the attachment
                            SELECT NVL (MAX (seq_num), 0) + 10
                              INTO ln_seq_num
                              FROM fnd_attached_documents
                             WHERE     pk1_value =
                                       TO_CHAR (lcu_data.header_id)
                                   AND entity_name = 'OE_ORDER_HEADERS';

                            -- Attachment Creation
                            fnd_attached_documents_pkg.insert_row (
                                x_rowid                      => ln_rowid,
                                x_attached_document_id       =>
                                    ln_attached_document_id,
                                x_document_id                => ln_document_id,
                                x_creation_date              => SYSDATE,
                                x_created_by                 => gn_user_id,
                                x_last_update_date           => SYSDATE,
                                x_last_updated_by            => gn_user_id,
                                x_last_update_login          => gn_login_id,
                                x_seq_num                    => ln_seq_num,
                                x_entity_name                => 'OE_ORDER_HEADERS',
                                x_column1                    => NULL,
                                x_pk1_value                  => lcu_data.header_id,
                                x_pk2_value                  => NULL,
                                x_pk3_value                  => NULL,
                                x_pk4_value                  => NULL,
                                x_pk5_value                  => NULL,
                                x_automatically_added_flag   => 'N',
                                x_datatype_id                =>
                                    ln_short_datatype_id,
                                x_category_id                =>
                                    lcu_data.category_id,
                                x_security_type              => 4,
                                x_security_id                => NULL,
                                x_publish_flag               => 'Y',
                                x_language                   =>
                                    USERENV ('LANG'),
                                x_description                =>
                                    lcu_data.file_name,
                                x_file_name                  =>
                                    lcu_data.file_name,
                                x_media_id                   => ln_media_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Created Attachment '
                                || ln_attached_document_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_status   := 'E';
                                lc_error_message   :=
                                       'Attachment Exception - '
                                    || SUBSTR (SQLERRM, 1, 3950);
                                ROLLBACK TO before_document;
                        END;
                    END IF;                                         --Document
                END IF;                                                  --LOB
            ELSE
                lc_status          := 'E';
                lc_error_message   := 'File Data is empty';
            END IF;

            -- Update status
            UPDATE xxd_ont_edi_order_instrs_t
               SET status = lc_status, error_message = lc_error_message, request_id = fnd_global.conc_request_id,
                   last_updated_by = gn_user_id, last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE instruction_id = lcu_data.instruction_id;
        END LOOP;

        -- Start changes for CCR0008045
        -- Update Order Dff with Musical Or Solid Type
        MERGE INTO oe_order_headers_all ooha
             USING (SELECT ooh.header_id,
                           ooh.org_id,
                           DECODE (
                               (SELECT COUNT (1)
                                  FROM xxdo.xxd_ont_edi_order_instrs_t xxd
                                 WHERE     xxd.orig_sys_document_ref =
                                           ooh.orig_sys_document_ref
                                       AND xxd.status = 'S'
                                       AND xxd.instruction_category =
                                           'OM - Packing Instructions'),
                               0, 'S',
                               'M') pack_type
                      FROM oe_order_headers_all ooh
                     WHERE     ooh.open_flag = 'Y'
                           AND NVL (ooh.attribute16, 'N') = 'N'
                           AND ooh.org_id = p_org_id
                           AND ((p_orig_sys_document_ref IS NOT NULL AND ooh.orig_sys_document_ref = p_orig_sys_document_ref) OR (p_orig_sys_document_ref IS NULL AND 1 = 1)))
                   ord_dtls
                ON (ooha.header_id = ord_dtls.header_id AND ooha.org_id = ord_dtls.org_id)
        WHEN MATCHED
        THEN
            UPDATE SET ooha.attribute16 = ord_dtls.pack_type, ooha.request_id = fnd_global.conc_request_id, ooha.last_updated_by = gn_user_id,
                       ooha.last_update_date = SYSDATE, ooha.last_update_login = gn_login_id;
    -- End changes for CCR0008045
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (fnd_file.LOG, 'Main Exception - ' || x_errbuf);
    END create_attach_documents;
END xxd_ont_edi_order_instrs_pkg;
/
