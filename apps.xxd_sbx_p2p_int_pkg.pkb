--
-- XXD_SBX_P2P_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SBX_P2P_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_SBX_P2P_INT_PKG
    * Design       : This package will be used as hook in the Sabix Tax determination package
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 27-JUL-2020  1.0        Deckers                 Initial Version
    -- 02-APR-2021  1.1        Srinath Siricilla       CCR0009031
    -- 13-APR-2021  1.2        Srinath Siricilla       CCR0009257
    -- 01-DEC-2021  2.0        Srinath Siricilla       CCR0009727
    ******************************************************************************************/

    g_debug_level      VARCHAR2 (50) := fnd_profile.VALUE ('SABRIX_DEBUG_LEVEL');
    gv_host   CONSTANT VARCHAR2 (30)
                           := fnd_profile.VALUE ('SABRIX_HOSTED_IDENTIFIER') ; -- Added as per CCR0009257

    PROCEDURE update_header_prc (p_batch_id IN NUMBER, p_header_id IN NUMBER, -- Added as per CCR0009257
                                                                              p_calling_system_number IN NUMBER, p_ext_company_id IN VARCHAR2:= NULL, -- End of Change
                                                                                                                                                      p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL, p_user_element_attribute8 IN VARCHAR2:= NULL
                                 , p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL, p_user_element_attribute11 IN VARCHAR2:= NULL -- Added as per CCR0009727
                                                                                                                                                                             )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        NULL;
        lv_location    := 'update_header_prc';
        lv_procedure   := 'update_header_prc';

        debug_prc (
            p_batch_id,
            lv_location,
            lv_procedure,
               'The values passed for Header Update are - attribute1 is - '
            || p_user_element_attribute1
            || ' - Attribute2 is - '
            || p_user_element_attribute2
            || ' - Attribute3 is - '
            || p_user_element_attribute3
            || ' - Attribute4 is - '
            || p_user_element_attribute4
            || ' - Attribute5 is - '
            || p_user_element_attribute5
            || ' - Attribute6 is - '
            || p_user_element_attribute6
            || ' - Attribute7 is - '
            || p_user_element_attribute7
            || ' - Attribute8 is - '
            || p_user_element_attribute8
            || ' - Attribute9 is - '
            || p_user_element_attribute9
            || ' - Attribute10 is - '
            || p_user_element_attribute10
            -- -- Added as per CCR0009727
            || ' - Attribute11 is - '
            || p_user_element_attribute11
            -- End of Change for CCR0009727
            -- Added as per CCR0009257
            || ' - External Company ID is - '
            || p_ext_company_id
            -- End of Change
            || ' - For Batch ID - '
            || p_batch_id
            || ' - Header ID is - '
            || p_header_id
            -- Start of Change for CCR0009257
            || ' - With Call System Number is - '
            || p_calling_system_number                        -- End of Change
                                      );

        -- Added as per CCR0009257

        IF p_calling_system_number = '200'
        THEN
            UPDATE sabrix_invoice
               SET user_element_attribute1   =
                       NVL (p_user_element_attribute1,
                            user_element_attribute1),
                   user_element_attribute2   =
                       NVL (p_user_element_attribute2,
                            user_element_attribute2),
                   user_element_attribute3   =
                       NVL (p_user_element_attribute3,
                            user_element_attribute3),
                   user_element_attribute4   =
                       NVL (p_user_element_attribute4,
                            user_element_attribute4),
                   user_element_attribute5   =
                       NVL (p_user_element_attribute5,
                            user_element_attribute5),
                   user_element_attribute6   =
                       NVL (p_user_element_attribute6,
                            user_element_attribute6),
                   user_element_attribute7   =
                       NVL (p_user_element_attribute7,
                            user_element_attribute7),
                   user_element_attribute8   =
                       NVL (p_user_element_attribute8,
                            user_element_attribute8),
                   user_element_attribute9   =
                       NVL (p_user_element_attribute9,
                            user_element_attribute9),
                   user_element_attribute10   =
                       NVL (p_user_element_attribute10,
                            user_element_attribute10),
                   -- Added as per CCR0009727
                   user_element_attribute11   =
                       NVL (p_user_element_attribute11,
                            user_element_attribute11),
                   -- End of Change CCR0009727
                   external_company_id   =
                       NVL (REGEXP_SUBSTR (external_company_id, '[^-]+', 1,
                                           2),
                            p_ext_company_id)
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND user_element_attribute41 = p_header_id;
        -- Added as per CCR0009257
        ELSE
            UPDATE sabrix_invoice
               SET user_element_attribute1 = NVL (p_user_element_attribute1, user_element_attribute1), --lv_tax_class,
                                                                                                       user_element_attribute2 = NVL (p_user_element_attribute2, user_element_attribute2), user_element_attribute3 = NVL (p_user_element_attribute3, user_element_attribute3),
                   user_element_attribute4 = NVL (p_user_element_attribute4, user_element_attribute4), user_element_attribute5 = NVL (p_user_element_attribute5, user_element_attribute5), user_element_attribute6 = NVL (p_user_element_attribute6, user_element_attribute6),
                   user_element_attribute7 = NVL (p_user_element_attribute7, user_element_attribute7), user_element_attribute8 = NVL (p_user_element_attribute8, user_element_attribute8), user_element_attribute9 = NVL (p_user_element_attribute9, user_element_attribute9),
                   user_element_attribute10 = NVL (p_user_element_attribute10, user_element_attribute10), -- Added as per CCR0009727
                                                                                                          user_element_attribute11 = NVL (p_user_element_attribute11, user_element_attribute11)
             -- End of Change CCR0009727
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND user_element_attribute41 = p_header_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, lv_procedure, lv_location,
                       'Error updating inv header' || SQLERRM);
    END update_header_prc;

    PROCEDURE update_line_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER, p_line_id IN NUMBER, p_user_element_attribute1 IN VARCHAR2:= NULL, p_user_element_attribute2 IN VARCHAR2:= NULL, p_user_element_attribute3 IN VARCHAR2:= NULL, p_user_element_attribute4 IN VARCHAR2:= NULL, p_user_element_attribute5 IN VARCHAR2:= NULL, p_user_element_attribute6 IN VARCHAR2:= NULL, p_user_element_attribute7 IN VARCHAR2:= NULL, p_user_element_attribute8 IN VARCHAR2:= NULL, p_user_element_attribute9 IN VARCHAR2:= NULL, p_user_element_attribute10 IN VARCHAR2:= NULL, p_user_element_attribute11 IN VARCHAR2:= NULL, -- Added as per CCR0009727
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_transaction_type IN VARCHAR2:= NULL
                               , p_sf_country IN VARCHAR2:= NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        NULL;
        lv_location    := 'update_line_prc';
        lv_procedure   := 'update_line_prc';

        debug_prc (
            p_batch_id,
            lv_location,
            lv_procedure,
               'The values passed for Update are - attribute1 is - '
            || p_user_element_attribute1
            || ' - Attribute2 is - '
            || p_user_element_attribute2
            || ' - Attribute3 is - '
            || p_user_element_attribute3
            || ' - Attribute4 is - '
            || p_user_element_attribute4
            || ' - Attribute5 is - '
            || p_user_element_attribute5
            || ' - Attribute6 is - '
            || p_user_element_attribute6
            || ' - Attribute7 is - '
            || p_user_element_attribute7
            || ' - Attribute8 is - '
            || p_user_element_attribute8
            || ' - Attribute9 is - '
            || p_user_element_attribute9
            || ' - Attribute10 is - '
            || p_user_element_attribute10
            -- -- Added as per CCR0009727
            || ' - Attribute11 is - '
            || p_user_element_attribute11
            -- End of Change for CCR0009727
            || ' - Trx Type is - '
            || p_transaction_type
            || ' - sf country is - '
            || p_sf_country
            || ' - For Invoice ID - '
            || p_inv_id
            || ' - Line ID is - '
            || p_line_id);


        UPDATE sabrix_line
           SET user_element_attribute1 = NVL (p_user_element_attribute1, user_element_attribute1), --lv_tax_class,
                                                                                                   user_element_attribute2 = NVL (p_user_element_attribute2, user_element_attribute2), user_element_attribute3 = NVL (p_user_element_attribute3, user_element_attribute3),
               user_element_attribute4 = NVL (p_user_element_attribute4, user_element_attribute4), user_element_attribute5 = NVL (p_user_element_attribute5, user_element_attribute5), user_element_attribute6 = NVL (p_user_element_attribute6, user_element_attribute6),
               user_element_attribute7 = NVL (p_user_element_attribute7, user_element_attribute7), user_element_attribute8 = NVL (p_user_element_attribute8, user_element_attribute8), user_element_attribute9 = NVL (p_user_element_attribute9, user_element_attribute9),
               user_element_attribute10 = NVL (p_user_element_attribute10, user_element_attribute10), -- Added as per CCR0009727
                                                                                                      user_element_attribute11 = NVL (p_user_element_attribute11, user_element_attribute11), -- End of Change for CCR0009727
                                                                                                                                                                                             transaction_type = NVL (p_transaction_type, transaction_type),
               sf_country = NVL (p_sf_country, sf_country)
         WHERE     1 = 1
               AND batch_id = p_batch_id
               AND invoice_id = p_inv_id
               AND user_element_attribute41 = p_line_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, lv_procedure, lv_location,
                       'Error updating inv' || SQLERRM);
    END update_line_prc;

    PROCEDURE debug_prc (p_batch_id NUMBER, p_procedure VARCHAR2, p_location VARCHAR2
                         , p_message VARCHAR2, p_severity VARCHAR2 DEFAULT 0)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF g_debug_level IS NOT NULL AND g_debug_level IN ('ALL', 'USER')
        THEN
            INSERT INTO sabrix_log (log_date, instance_name, batch_id,
                                    log_id, document_num, procedure_name,
                                    location, severity, MESSAGE,
                                    extended_message)
                 VALUES (SYSDATE, sabrix_log_pkg.g_instance_name, p_batch_id,
                         sabrix_log_id_seq.NEXTVAL, sabrix_log_pkg.g_invoice_number, p_procedure, p_location, p_severity, SUBSTR (p_message, 1, 4000)
                         , NULL);

            COMMIT;
        END IF;
    END debug_prc;

    PROCEDURE update_inv_prc (p_batch_id IN NUMBER, p_inv_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        lv_db_name   VARCHAR2 (10);
    BEGIN
        lv_db_name     := NULL;

        lv_location    := 'update_inv';
        lv_procedure   := 'update_inv_prc';

        BEGIN
            SELECT name INTO lv_db_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_db_name   := 'NONPROD';
        END;

        debug_prc (p_batch_id, 'update_inv', 'update_inv_prc',
                   'upd start with db as - ' || lv_db_name);

        UPDATE sabrix_invoice
           SET (username, password)     =
                   (SELECT flvv.description username, flvv.tag pwd
                      FROM fnd_lookup_values_vl flvv
                     WHERE     flvv.lookup_type = 'XXD_AR_SBX_CONN_DTLS_LKP'
                           AND flvv.lookup_code =
                               DECODE (lv_db_name,
                                       'EBSPROD', 'EBSPROD',
                                       'NONPROD')
                           AND flvv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           flvv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           flvv.end_date_active,
                                                           TRUNC (SYSDATE))), --      UPDATE sabrix_invoice
               user_element_attribute1   = p_inv_id
         WHERE batch_id = p_batch_id;

        COMMIT;
    --      UPDATE sabrix_invoice
    --         SET (username, password) =
    --                (SELECT flvv.description username, flvv.tag pwd
    --                   FROM fnd_lookup_values_vl flvv, v$database vd
    --                  WHERE     flvv.lookup_type = 'XXD_AR_SBX_CONN_DTLS_LKP'
    --                        AND flvv.lookup_code = vd.name
    --                        AND flvv.enabled_flag = 'Y'
    --                        AND TRUNC (SYSDATE) BETWEEN NVL (
    --                                                       flvv.start_date_active,
    --                                                       TRUNC (SYSDATE))
    --                                                AND NVL (
    --                                                       flvv.end_date_active,
    --                                                       TRUNC (SYSDATE))
    --                        AND flvv.lookup_code = 'EBSPROD'
    --                 UNION
    --                 SELECT flvv.description username, flvv.tag pwd
    --                   FROM fnd_lookup_values_vl flvv
    --                  WHERE     flvv.lookup_type = 'XXD_AR_SBX_CONN_DTLS_LKP'
    --                        AND flvv.enabled_flag = 'Y'
    --                        AND TRUNC (SYSDATE) BETWEEN NVL (
    --                                                       flvv.start_date_active,
    --                                                       TRUNC (SYSDATE))
    --                                                AND NVL (
    --                                                       flvv.end_date_active,
    --                                                       TRUNC (SYSDATE))
    --                        AND flvv.lookup_code <> 'EBSPROD'),
    --             user_element_attribute1 = p_inv_id
    --       WHERE batch_id = p_batch_id;
    --
    --      COMMIT;

    --      debug_prc (p_batch_id,
    --                 lv_procedure,
    --                 lv_location,
    --                 'upd end');
    -- COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_prc (p_batch_id, lv_procedure, lv_location,
                       'Error updating inv' || SQLERRM);
    END update_inv_prc;

    PROCEDURE xxd_po_sbx_pre_calc_prc (p_batch_id IN NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_po_hdr_data IS
            SELECT sbx_inv.batch_id, sbx_inv.invoice_id, sbx_inv.user_element_attribute41 phdr_id,
                   sbx_inv.user_element_attribute44, sbx_inv.calling_system_number, -- Added as per CCR0009257
                                                                                    sbx_inv.external_company_id
              FROM sabrix_invoice sbx_inv          --, apps.po_headers_all pha
             WHERE     1 = 1
                   AND calling_system_number = '201' --AND sbx_inv.user_element_attribute44 = 'PO_PA'
                   AND sbx_inv.batch_id = p_batch_id;


        CURSOR cur_po_line_data (pn_batch_id IN NUMBER, pn_invoice_id IN NUMBER, pn_po_header_id IN NUMBER)
        IS
            SELECT user_element_attribute41
              FROM sabrix_line sbx_line
             WHERE     1 = 1
                   --AND sbx_line.user_element_attribute47 = 'PURCHASE_ORDER'
                   AND sbx_line.invoice_id = pn_invoice_id
                   AND sbx_line.batch_id = pn_batch_id;

        --      CURSOR cur_po_hdr_data
        --      IS
        --         SELECT sbx_inv.batch_id,
        --                sbx_inv.invoice_id,
        --                sbx_inv.user_element_attribute41 phdr_id
        --           FROM sabrix_invoice sbx_inv             --, apps.po_headers_all pha
        --          WHERE     1 = 1
        --                AND calling_system_number = '201'
        --                AND sbx_inv.user_element_attribute44 = 'RELEASE'
        --                AND sbx_inv.batch_id = p_batch_id;

        l_boolean         BOOLEAN;
        lv_po_cat_seg1    VARCHAR2 (100);      --mtl_categories.segment1%TYPE;
        lv_po_cat_seg2    VARCHAR2 (100);      --mtl_categories.segment2%TYPE;
        lv_po_cat_seg3    VARCHAR2 (100);      --mtl_categories.segment3%TYPE;
        lv_req_cat_seg1   VARCHAR2 (100);      --mtl_categories.segment1%TYPE;
        lv_req_cat_seg2   VARCHAR2 (100);      --mtl_categories.segment2%TYPE;
        lv_req_cat_seg3   VARCHAR2 (100);      --mtl_categories.segment3%TYPE;
        ln_category_id    VARCHAR2 (100);   --mtl_categories.category_id%TYPE;
        ln_po_header_c    NUMBER;
        l_exception_msg   VARCHAR2 (4000);
        ln_req_c          NUMBER;
        lv_procedure      VARCHAR2 (100);
        lv_location       VARCHAR2 (100);
        lv_type           VARCHAR2 (100);
        lv_source_code    VARCHAR2 (100);
        lv_error_msg      VARCHAR2 (4000);
        lv_dist_seg6      VARCHAR2 (100);           -- Added as per CCR0009727
        lv_is_asset       VARCHAR2 (100);           -- Added as per CCR0009727
        lv_asset_seg6     VARCHAR2 (100);           -- Added as per CCR0009727
    BEGIN
        lv_procedure     := 'XXD_PO_SBX_PRE_CALC_PRC';
        lv_location      := 'First Entry Point';
        lv_type          := NULL;
        lv_source_code   := NULL;
        lv_error_msg     := NULL;

        debug_prc (p_batch_id, lv_procedure, lv_location,
                   'Start of Data flow');

        FOR po_hdr IN cur_po_hdr_data
        LOOP
            IF po_hdr.user_element_attribute44 = 'PO_PA'
            THEN
                update_inv_prc (p_batch_id, po_hdr.phdr_id);

                l_exception_msg   := NULL;

                BEGIN
                    SELECT po_header_id, type_lookup_code, document_creation_method
                      INTO ln_po_header_c, lv_type, lv_source_code
                      FROM apps.po_headers_all
                     WHERE po_header_id = po_hdr.phdr_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_po_header_c    := NULL;
                        l_exception_msg   := SUBSTR (SQLERRM, 1, 200);
                        lv_location       := 'Check PO Exists';

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'PO Header ID is not found in PO_HEADERS_ALL for po_hdr.po_header_id - '
                            || po_hdr.phdr_id
                            || ' with error message - '
                            || l_exception_msg);
                END;


                IF ln_po_header_c IS NOT NULL
                THEN
                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'PO Header ID is found in PO_HEADERS_ALL for po_hdr.po_header_id - '
                        || po_hdr.phdr_id);
                END IF;

                update_header_prc (
                    p_batch_id                  => po_hdr.batch_id,
                    p_header_id                 => po_hdr.phdr_id,
                    p_calling_system_number     => po_hdr.calling_system_number, -- Added as per CCR0009257
                    p_user_element_attribute1   => lv_type,
                    p_user_element_attribute2   => lv_source_code);

                --            UPDATE sabrix_invoice
                --               SET user_element_attribute1 = lv_type,
                --                   user_element_attribute2 = lv_source_code
                --             WHERE     batch_id = po_hdr.batch_id
                --                   AND user_element_attribute41 = po_hdr.phdr_id;

                FOR po_line
                    IN cur_po_line_data (po_hdr.batch_id,
                                         po_hdr.invoice_id,
                                         po_hdr.phdr_id)
                LOOP
                    l_boolean        := NULL;
                    lv_po_cat_seg1   := NULL;
                    lv_po_cat_seg2   := NULL;
                    lv_po_cat_seg3   := NULL;
                    ln_category_id   := NULL;
                    lv_location      := 'PO Lines Cursor';

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Start of Line Values are to be derived for Input Values batch_id - '
                        || po_hdr.batch_id
                        || ' and invoice id - '
                        || po_hdr.invoice_id
                        || ' and PO Header id - '
                        || po_hdr.phdr_id
                        || ' and PO Line Location ID - '
                        || po_line.user_element_attribute41);

                    -- Using the line location id, fetch the Category ID

                    lv_dist_seg6     := NULL;      --  Added as per CCR0009727

                    BEGIN
                        SELECT pla.category_id, gcc.segment6
                          INTO ln_category_id, lv_dist_seg6
                          FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda --  Added as per CCR0009727
                                                                                                     ,
                               gl_code_combinations gcc --  Added as per CCR0009727
                         WHERE     pla.po_line_id = plla.po_line_id
                               AND plla.line_location_id =
                                   po_line.user_element_attribute41
                               AND pda.line_location_id =
                                   plla.line_location_id --  Added as per CCR0009727
                               AND pda.code_combination_id =
                                   gcc.code_combination_id; --  Added as per CCR0009727

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Category ID fetched is  - '
                            || ln_category_id
                            || ' for line location id - '
                            || po_line.user_element_attribute41);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_category_id   := NULL;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   'Exception Fetch Category  - '
                                || SUBSTR (SQLERRM, 1, 200)
                                || ' for line location id - '
                                || po_line.user_element_attribute41);
                    END;

                    lv_error_msg     := NULL;
                    lv_location      := 'get_category_seg_fnc';

                    l_boolean        :=
                        get_category_seg_fnc (ln_category_id, lv_po_cat_seg1, lv_po_cat_seg2
                                              , lv_po_cat_seg3, lv_error_msg);

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Getting the Category Segment values - '
                        || lv_po_cat_seg1
                        || ' and seg2 - '
                        || lv_po_cat_seg2
                        || ' and seg3 - '
                        || lv_po_cat_seg3
                        || ' Error Msg if Exists - '
                        || lv_error_msg);

                    -- Start of Change for CCR0009727

                    -- Set Attribute11 as 'ASSET' for the Asset Categories.

                    lv_asset_seg6    := NULL;

                    IF lv_po_cat_seg1 = 'Non-Trade'
                    THEN
                        BEGIN
                            SELECT segment6
                              INTO lv_asset_seg6
                              FROM fa_book_controls fbc, gl_code_combinations_kfv gcc
                             WHERE     1 = 1
                                   AND fbc.flexbuilder_defaults_ccid =
                                       gcc.code_combination_id
                                   AND fbc.book_class = 'CORPORATE'
                                   AND REGEXP_SUBSTR (po_hdr.external_company_id, '[^-]+', 1
                                                      , 2) = gcc.segment1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_asset_seg6   := NULL;
                        END;

                        IF lv_dist_seg6 = lv_asset_seg6
                        THEN
                            lv_is_asset   := 'ASSET';
                        ELSE
                            lv_is_asset   := NULL;
                        END IF;
                    END IF;

                    -- End of Change for CCR0009727


                    update_line_prc (
                        p_batch_id                   => po_hdr.batch_id,
                        p_inv_id                     => po_hdr.invoice_id,
                        p_line_id                    => po_line.user_element_attribute41,
                        p_user_element_attribute1    => lv_po_cat_seg1,
                        p_user_element_attribute2    =>
                            lv_po_cat_seg2 || '.' || lv_po_cat_seg3,
                        p_user_element_attribute6    => lv_po_cat_seg2,
                        p_user_element_attribute7    => lv_po_cat_seg3,
                        p_transaction_type           => 'GS',
                        p_user_element_attribute11   => lv_is_asset -- Added as per CCR0009727
                                                                   );
                END LOOP;
            --      update_inv_prc (p_batch_id, po_hdr.phdr_id);
            ELSIF po_hdr.user_element_attribute44 = 'RELEASE'
            THEN
                update_inv_prc (p_batch_id, po_hdr.phdr_id);

                l_exception_msg   := NULL;

                BEGIN
                    SELECT po_header_id, type_lookup_code, document_creation_method
                      INTO ln_po_header_c, lv_type, lv_source_code
                      FROM apps.po_headers_all pha
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.po_releases_all pra
                                     WHERE     pra.po_header_id =
                                               pha.po_header_id
                                           AND pra.po_release_id =
                                               po_hdr.phdr_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_po_header_c    := NULL;
                        l_exception_msg   := SUBSTR (SQLERRM, 1, 200);
                        lv_location       := 'Check PO Exists';

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'PO Header ID is not found in PO_HEADERS_ALL for po_hdr.po_header_id - '
                            || po_hdr.phdr_id
                            || ' with error message - '
                            || l_exception_msg);
                END;


                IF ln_po_header_c IS NOT NULL
                THEN
                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'PO Header ID is found in PO_HEADERS_ALL for po_hdr.po_header_id - '
                        || po_hdr.phdr_id);
                END IF;

                --            UPDATE sabrix_invoice
                --               SET user_element_attribute1 = lv_type,
                --                   user_element_attribute2 = lv_source_code
                --             WHERE     batch_id = po_hdr.batch_id
                --                   AND user_element_attribute41 = po_hdr.phdr_id;

                update_header_prc (
                    p_batch_id                  => po_hdr.batch_id,
                    p_header_id                 => po_hdr.phdr_id,
                    p_calling_system_number     => po_hdr.calling_system_number, -- Added as per CCR0009257
                    p_user_element_attribute1   => lv_type,
                    p_user_element_attribute2   => lv_source_code);

                FOR po_line
                    IN cur_po_line_data (po_hdr.batch_id,
                                         po_hdr.invoice_id,
                                         po_hdr.phdr_id)
                LOOP
                    l_boolean        := NULL;
                    lv_po_cat_seg1   := NULL;
                    lv_po_cat_seg2   := NULL;
                    lv_po_cat_seg3   := NULL;
                    ln_category_id   := NULL;
                    lv_location      := 'PO Lines Cursor';

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'Start of Line Values are to be derived for Input Values batch_id - '
                        || po_hdr.batch_id
                        || ' and invoice id - '
                        || po_hdr.invoice_id
                        || ' and PO Header id - '
                        || po_hdr.phdr_id
                        || ' and PO Line Location ID - '
                        || po_line.user_element_attribute41);

                    -- Using the line location id, fetch the Category ID

                    lv_dist_seg6     := NULL;      --  Added as per CCR0009727

                    BEGIN
                        SELECT pla.category_id, gcc.segment6
                          INTO ln_category_id, lv_dist_seg6
                          FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda --  Added as per CCR0009727
                                                                                                     ,
                               gl_code_combinations gcc --  Added as per CCR0009727
                         WHERE     pla.po_line_id = plla.po_line_id
                               AND plla.line_location_id =
                                   po_line.user_element_attribute41
                               AND pda.line_location_id =
                                   plla.line_location_id --  Added as per CCR0009727
                               AND pda.code_combination_id =
                                   gcc.code_combination_id; --  Added as per CCR0009727

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Category ID fetched is  - '
                            || ln_category_id
                            || ' for line location id - '
                            || po_line.user_element_attribute41);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_category_id   := NULL;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   'Exception Fetch Category  - '
                                || SUBSTR (SQLERRM, 1, 200)
                                || ' for line location id - '
                                || po_line.user_element_attribute41);
                    END;

                    lv_error_msg     := NULL;
                    l_boolean        :=
                        get_category_seg_fnc (ln_category_id, lv_po_cat_seg1, lv_po_cat_seg2
                                              , lv_po_cat_seg3, lv_error_msg);

                    lv_location      := 'get_category_seg_fnc';

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           'For PO Line Getting the Category Segment values - '
                        || lv_po_cat_seg1
                        || ' and seg2 - '
                        || lv_po_cat_seg2
                        || ' and seg3 - '
                        || lv_po_cat_seg3
                        || ' Error Msg if Exists is - '
                        || lv_error_msg);

                    -- Start of Change for CCR0009727

                    -- Set Attribute11 as 'ASSET' for the Asset Categories.

                    lv_asset_seg6    := NULL;

                    IF lv_po_cat_seg1 = 'Non-Trade'
                    THEN
                        SELECT segment6
                          INTO lv_asset_seg6
                          FROM fa_book_controls fbc, gl_code_combinations_kfv gcc
                         WHERE     1 = 1
                               AND fbc.flexbuilder_defaults_ccid =
                                   gcc.code_combination_id
                               AND fbc.book_class = 'CORPORATE'
                               AND REGEXP_SUBSTR (po_hdr.external_company_id, '[^-]+', 1
                                                  , 2) = gcc.segment1;

                        IF lv_dist_seg6 = lv_asset_seg6
                        THEN
                            lv_is_asset   := 'ASSET';
                        ELSE
                            lv_is_asset   := NULL;
                        END IF;
                    END IF;

                    -- End of Change for CCR0009727

                    update_line_prc (
                        p_batch_id                   => po_hdr.batch_id,
                        p_inv_id                     => po_hdr.invoice_id,
                        p_line_id                    => po_line.user_element_attribute41,
                        p_user_element_attribute1    => lv_po_cat_seg1,
                        p_user_element_attribute2    =>
                            lv_po_cat_seg2 || '.' || lv_po_cat_seg3,
                        p_user_element_attribute6    => lv_po_cat_seg2,
                        p_user_element_attribute7    => lv_po_cat_seg3,
                        p_transaction_type           => 'GS',
                        p_user_element_attribute11   => lv_is_asset -- Added as per CCR0009727
                                                                   );
                END LOOP;
            END IF;
        END LOOP;
    END xxd_po_sbx_pre_calc_prc;

    PROCEDURE xxd_req_sbx_pre_calc_prc (p_batch_id IN NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_req_hdr_data IS
            SELECT pha.requisition_header_id, sbx_inv.batch_id, sbx_inv.invoice_id,
                   pha.type_lookup_code lkp_type, pha.interface_source_code source_code, sbx_inv.user_element_attribute45,
                   sbx_inv.user_element_attribute41, sbx_inv.external_company_id, -- Added as per CCR0009727
                                                                                  sbx_inv.calling_system_number -- Added as per CCR0009257
              FROM sabrix_invoice sbx_inv, apps.po_requisition_headers_all pha
             WHERE     1 = 1
                   AND calling_system_number = '201'
                   AND pha.requisition_header_id =
                       sbx_inv.user_element_attribute41
                   AND pha.org_id = sbx_inv.user_element_attribute45
                   AND sbx_inv.user_element_attribute44 = 'REQUISITION'
                   AND sbx_inv.batch_id = p_batch_id;

        CURSOR cur_req_line_data (pn_batch_id IN NUMBER, pn_invoice_id IN NUMBER, pn_req_header_id IN NUMBER)
        IS
            SELECT DISTINCT prla.category_id, user_element_attribute41, source_organization_id
              FROM sabrix_line sbx_line, apps.po_requisition_lines_all prla
             WHERE     1 = 1
                   AND prla.requisition_line_id =
                       sbx_line.user_element_attribute41
                   AND sbx_line.user_element_attribute47 = 'REQUISITION'
                   AND prla.requisition_header_id = pn_req_header_id
                   AND sbx_line.invoice_id = pn_invoice_id
                   AND sbx_line.batch_id = pn_batch_id;

        CURSOR cur_inv IS
            SELECT *
              FROM sabrix_invoice
             WHERE batch_id = p_batch_id;

        l_boolean            BOOLEAN;
        lv_req_cat_seg1      VARCHAR2 (100);   --mtl_categories.segment1%TYPE;
        lv_req_cat_seg2      VARCHAR2 (100);   --mtl_categories.segment2%TYPE;
        lv_req_cat_seg3      VARCHAR2 (100);   --mtl_categories.segment3%TYPE;
        ln_category_id       mtl_categories.category_id%TYPE;
        l_exception_msg      VARCHAR2 (4000);
        ln_req_c             NUMBER;
        lv_procedure         VARCHAR2 (100);
        lv_location          VARCHAR2 (100);
        ln_int_ship_org_id   NUMBER;
        lv_ship_location     VARCHAR2 (100);
        lv_error_msg         VARCHAR2 (4000);
        lv_dist_seg6         VARCHAR2 (100);        -- Added as per CCR0009727
        lv_is_asset          VARCHAR2 (100);        -- Added as per CCR0009727
        lv_asset_seg6        VARCHAR2 (100);        -- Added as per CCR0009727
    --      lv_source_code    VARCHAR2 (100);
    --      lv_type           VARCHAR2 (100);

    BEGIN
        lv_procedure   := 'XXD_REQ_SBX_PRE_CALC_PRC';
        lv_location    := 'First Entry Point';

        debug_prc (p_batch_id, lv_procedure, lv_location,
                   'Start of Data flow for Req');

        FOR req_hdr IN cur_req_hdr_data
        LOOP
            l_exception_msg   := NULL;

            update_inv_prc (p_batch_id, req_hdr.requisition_header_id);

            BEGIN
                SELECT requisition_header_id
                  INTO ln_req_c
                  FROM apps.po_requisition_headers_all
                 WHERE requisition_header_id = req_hdr.requisition_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_req_c          := NULL;
                    l_exception_msg   := SUBSTR (SQLERRM, 1, 200);

                    SABRIX_LOG_PKG.put_line (
                        p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                        p_location      => 'Header Loop Entry',
                        p_message       =>
                               'Req Header ID is not found in po_requisition_headers_all for req_hdr.requisition_header_id - '
                            || req_hdr.requisition_header_id
                            || ' with error message - '
                            || l_exception_msg,
                        p_output_type   => 'LOG',
                        p_severity      => sabrix_log_pkg.k_info);
            END;


            IF ln_req_c IS NOT NULL
            THEN
                SABRIX_LOG_PKG.put_line (
                    p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                    p_location      => 'Header Loop Entry',
                    p_message       =>
                           'Req Header ID is found in po_requisition_headers_all for req_hdr.requisition_header_id - '
                        || req_hdr.requisition_header_id,
                    p_output_type   => 'LOG',
                    p_severity      => sabrix_log_pkg.k_info);
            END IF;

            SABRIX_LOG_PKG.put_line (
                p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                p_location      => 'get_category_seg_fnc for Requisition',
                p_message       =>
                       'Start of Header Values are to be derived for Input Values batch_id - '
                    || req_hdr.batch_id
                    || ' and invoice id - '
                    || req_hdr.invoice_id
                    || ' and PO Header id - '
                    || req_hdr.requisition_header_id,
                p_output_type   => 'LOG',
                p_severity      => sabrix_log_pkg.k_info);


            --         UPDATE sabrix_invoice
            --            SET user_element_attribute1 = req_hdr.lkp_type,
            --                user_element_attribute2 = req_hdr.source_code
            --          WHERE     batch_id = req_hdr.batch_id
            --                AND user_element_attribute41 =
            --                       req_hdr.user_element_attribute41;

            --                AND user_element_attribute45 =
            --                       req_hdr.user_element_attribute45;

            update_header_prc (
                p_batch_id                  => req_hdr.batch_id,
                p_header_id                 => req_hdr.user_element_attribute41,
                p_calling_system_number     => req_hdr.calling_system_number, -- Added as per CCR0009257
                p_user_element_attribute1   => req_hdr.lkp_type,
                p_user_element_attribute2   => req_hdr.source_code);

            FOR req_line
                IN cur_req_line_data (req_hdr.batch_id,
                                      req_hdr.invoice_id,
                                      req_hdr.requisition_header_id)
            LOOP
                l_boolean            := NULL;
                lv_error_msg         := NULL;
                lv_req_cat_seg1      := NULL;
                lv_req_cat_seg2      := NULL;
                lv_req_cat_seg3      := NULL;
                lv_ship_location     := NULL;
                ln_int_ship_org_id   := NULL;

                lv_dist_seg6         := NULL;       -- Added as per CCR0009727
                lv_is_asset          := NULL;       -- Added as per CCR0009727
                lv_asset_seg6        := NULL;       -- Added as per CCR0009727

                SABRIX_LOG_PKG.put_line (
                    p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                    p_location      =>
                        'get_category_seg_fnc for Requisition Lines',
                    p_message       =>
                           'Start of Line Values are to be derived for Input Values batch_id - '
                        || req_hdr.batch_id
                        || ' and invoice id - '
                        || req_hdr.invoice_id
                        || ' and PO Header id - '
                        || req_hdr.requisition_header_id
                        || ' and PO Category id - '
                        || req_line.category_id,
                    p_output_type   => 'LOG',
                    p_severity      => sabrix_log_pkg.k_info);


                lv_error_msg         := NULL;
                l_boolean            :=
                    get_category_seg_fnc (req_line.category_id, lv_req_cat_seg1, lv_req_cat_seg2
                                          , lv_req_cat_seg3, lv_error_msg);

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       'Getting the Req Category Segment values - '
                    || lv_req_cat_seg1
                    || ' and seg2 - '
                    || lv_req_cat_seg2
                    || ' and seg3 - '
                    || lv_req_cat_seg3
                    || ' Error Msg if Exists - '
                    || lv_error_msg);



                SABRIX_LOG_PKG.put_line (
                    p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                    p_location      => 'get_category_seg_fnc for Requisition',
                    p_message       =>
                           'Getting the Segment - '
                        || lv_req_cat_seg1
                        || ' and Conc Seg - '
                        || lv_req_cat_seg2,
                    p_output_type   => 'LOG',
                    p_severity      => sabrix_log_pkg.k_info);

                -- Added as per CCR0009727

                IF lv_req_cat_seg1 = 'Non-Trade'
                THEN
                    lv_dist_seg6   := NULL;

                    BEGIN
                        SELECT gcc.segment6
                          INTO lv_dist_seg6
                          FROM po_req_distributions_all prda --  Added as per CCR0009727
                                                            , gl_code_combinations gcc --  Added as per CCR0009727
                         WHERE     1 = 1
                               AND prda.requisition_line_id =
                                   req_line.user_element_attribute41
                               AND prda.code_combination_id =
                                   gcc.code_combination_id; --  Added as per CCR0009727

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               'Segment 6 Fetched is   - '
                            || lv_dist_seg6
                            || ' for requisition line id - '
                            || req_line.user_element_attribute41);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_dist_seg6   := NULL;

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   'Exception in Fetching Segment6  - '
                                || SUBSTR (SQLERRM, 1, 200)
                                || ' for Req line id - '
                                || req_line.user_element_attribute41);
                    END;

                    BEGIN
                        SELECT segment6
                          INTO lv_asset_seg6
                          FROM fa_book_controls fbc, gl_code_combinations_kfv gcc
                         WHERE     1 = 1
                               AND fbc.flexbuilder_defaults_ccid =
                                   gcc.code_combination_id
                               AND fbc.book_class = 'CORPORATE'
                               AND REGEXP_SUBSTR (req_hdr.external_company_id, '[^-]+', 1
                                                  , 2) = gcc.segment1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_asset_seg6   := NULL;
                    END;

                    --                    debug_prc (
                    --                         p_batch_id,
                    --                         lv_procedure,
                    --                         lv_location,
                    --                            'Segment 6 Fetched is   - '
                    --                         || lv_dist_seg6
                    --                         || ' for requisition line id - '
                    --                         || req_line.user_element_attribute41);

                    IF lv_dist_seg6 = lv_asset_seg6
                    THEN
                        lv_is_asset   := 'ASSET';
                    ELSE
                        lv_is_asset   := NULL;
                    END IF;
                END IF;

                -- End of Change for CCR0009727

                lv_location          :=
                    'Validating IR Order and Ship from Det';

                --- for Internal Requisistions get the SF country

                IF req_hdr.lkp_type = 'INTERNAL'
                THEN
                    SABRIX_LOG_PKG.put_line (
                        p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                        p_location      => 'IR ship from country',
                        p_message       =>
                               'Getting the IR Ship from Country - '
                            || req_line.source_organization_id
                            || ' For Req line ID - '
                            || req_line.user_element_attribute41,
                        p_output_type   => 'LOG',
                        p_severity      => sabrix_log_pkg.k_info);

                    IF req_line.source_organization_id IS NOT NULL
                    THEN
                        lv_error_msg   := NULL;
                        lv_ship_location   :=
                            get_ship_from_fnc (
                                req_line.source_organization_id,
                                lv_error_msg);
                    END IF;

                    SABRIX_LOG_PKG.put_line (
                        p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                        p_location      => 'IR ship from country',
                        p_message       =>
                               'IR Ship from Country is - '
                            || lv_ship_location
                            || ' For Req line ID - '
                            || req_line.user_element_attribute41,
                        p_output_type   => 'LOG',
                        p_severity      => sabrix_log_pkg.k_info);
                END IF;


                /*IF req_hdr.lkp_type = 'INTERNAL'
                THEN
                   BEGIN
                      SELECT ool.ship_from_org_id
                        INTO ln_int_ship_org_id
                        FROM apps.oe_order_headers_all ooh,
                             apps.oe_order_lines_all ool,
                             apps.oe_order_sources oos,
                             apps.po_requisition_lines_all prl,
                             apps.po_requisition_headers_all prh
                       WHERE     1 = 1
                             AND ooh.org_id = ool.org_id
                             AND ooh.header_id = ool.header_id
                             AND ool.cancelled_flag = 'N'
                             AND ool.order_source_id = oos.order_source_id
                             AND UPPER (oos.name) = 'INTERNAL'
                             AND ool.source_document_line_id =
                                    prl.requisition_line_id
                             AND ool.source_document_id =
                                    prh.requisition_header_id
                             AND ooh.orig_sys_document_ref = prh.segment1 -- You can input Requisition number
                             AND prh.requisition_header_id =
                                    prl.requisition_header_id
                             AND prh.type_lookup_code = 'INTERNAL'
                             AND prl.requisition_line_id =
                                    req_line.user_element_attribute41;

                      SABRIX_LOG_PKG.put_line (
                         p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                         p_location      => 'IR ship from country',
                         p_message       =>    'Getting the IR Ship from Country - '
                                            || ln_int_ship_org_id
                                            || ' For Req line ID - '
                                            || req_line.user_element_attribute41,
                         p_output_type   => 'LOG',
                         p_severity      => sabrix_log_pkg.k_info);
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         l_exception_msg := SUBSTR (SQLERRM, 1, 200);
                         ln_int_ship_org_id := NULL;
                         SABRIX_LOG_PKG.put_line (
                            p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                            p_location      => 'IR ship from country',
                            p_message       =>    'Exception While fetching the IR Ship from Country for line ID - '
                                               || req_line.user_element_attribute41
                                               || ' Msg is - '
                                               || l_exception_msg,
                            p_output_type   => 'LOG',
                            p_severity      => sabrix_log_pkg.k_info);
                   END;

                   IF ln_int_ship_org_id IS NOT NULL
                   THEN
                    lv_ship_location := get_ship_from_fnc (ln_int_ship_org_id);

                   END IF;

                   SABRIX_LOG_PKG.put_line (
                         p_procedure     => 'XXD_REQ_SBX_PRE_CALC_PRC',
                         p_location      => 'IR ship from country',
                         p_message       =>    'IR Ship from Country is - '
                                            || lv_ship_location
                                            || ' For Req line ID - '
                                            || req_line.user_element_attribute41,
                         p_output_type   => 'LOG',
                         p_severity      => sabrix_log_pkg.k_info);

                END IF;*/

                update_line_prc (
                    p_batch_id                   => req_hdr.batch_id,
                    p_inv_id                     => req_hdr.invoice_id,
                    p_line_id                    => req_line.user_element_attribute41,
                    p_user_element_attribute1    => lv_req_cat_seg1,
                    p_user_element_attribute2    =>
                        lv_req_cat_seg2 || '.' || lv_req_cat_seg3,
                    p_user_element_attribute6    => lv_req_cat_seg2,
                    p_user_element_attribute7    => lv_req_cat_seg3,
                    p_user_element_attribute10   =>
                        CASE
                            WHEN req_hdr.lkp_type = 'INTERNAL' THEN 10
                        END,
                    p_sf_country                 =>
                        CASE
                            WHEN req_hdr.lkp_type = 'INTERNAL'
                            THEN
                                lv_ship_location
                        END,
                    p_transaction_type           => 'GS',
                    p_user_element_attribute11   => lv_is_asset -- Added as per CCR0009727
                                                               );
            END LOOP;
        --         update_inv_prc (p_batch_id, req_hdr.requisition_header_id);
        END LOOP;
    --COMMIT;
    END xxd_req_sbx_pre_calc_prc;

    FUNCTION get_ship_from_fnc (pn_inv_org_id   IN     NUMBER,
                                x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ship_country   VARCHAR2 (100);
    BEGIN
        lv_ship_country   := NULL;

        SELECT fvl.territory_code
          INTO lv_ship_country
          FROM fnd_territories_vl fvl, hr_locations hrl, hr_all_organization_units hou
         WHERE     hrl.country = fvl.territory_code
               AND hrl.inventory_organization_id = hou.organization_id
               AND hrl.location_id = hou.location_id
               AND hrl.inventory_organization_id = pn_inv_org_id;

        RETURN lv_ship_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_ship_country   := NULL;
            x_err_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_ship_country;
    END get_ship_from_fnc;

    FUNCTION invoice_type_fnc (pn_invoice_id   IN     NUMBER,
                               x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_invoice_type   ap_invoices_all.invoice_type_lookup_code%TYPE;
    BEGIN
        NULL;

        SELECT invoice_type_lookup_code
          INTO lv_invoice_type
          FROM apps.ap_invoices_all
         WHERE invoice_id = pn_invoice_id;

        RETURN lv_invoice_type;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_invoice_type   := NULL;
            x_err_msg         := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_invoice_type;
    END invoice_type_fnc;

    FUNCTION invoice_source_fnc (pn_invoice_id   IN     NUMBER,
                                 x_err_msg          OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_invoice_source   ap_invoices_all.source%TYPE;
    BEGIN
        NULL;

        SELECT source
          INTO lv_invoice_source
          FROM apps.ap_invoices_all
         WHERE invoice_id = pn_invoice_id;

        RETURN lv_invoice_source;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_invoice_source   := NULL;
            x_err_msg           := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_invoice_source;
    END invoice_source_fnc;

    FUNCTION get_po_category_fnc (pn_header_id IN NUMBER, pn_line_loc_id IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_po_category_id   NUMBER;
    BEGIN
        ln_po_category_id   := NULL;


        IF pn_header_id IS NOT NULL
        THEN
            -- PO at Invoice header level can only be one value
            BEGIN
                SELECT DISTINCT category_id
                  INTO ln_po_category_id
                  FROM apps.po_lines_all
                 WHERE po_header_id = pn_header_id;

                RETURN ln_po_category_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_po_category_id   := NULL;
                    x_err_msg           := SUBSTR (SQLERRM, 1, 200);
                    RETURN ln_po_category_id;
            END;
        ELSIF pn_line_loc_id IS NOT NULL
        -- PO's at line level can have multiple, so joining with line location id from Sabix tables

        THEN
            BEGIN
                SELECT category_id
                  INTO ln_po_category_id
                  FROM apps.po_lines_all pla, apps.po_line_locations_all plla
                 WHERE     plla.po_line_id = pla.po_line_id
                       AND plla.line_location_id = pn_line_loc_id;

                RETURN ln_po_category_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_po_category_id   := NULL;
                    x_err_msg           := SUBSTR (SQLERRM, 1, 200);
                    RETURN ln_po_category_id;
            END;
        ELSE
            RETURN NULL;
        END IF;
    END;


    FUNCTION get_category_seg_fnc (pn_category_id   IN     NUMBER,
                                   x_seg1              OUT VARCHAR2,
                                   x_seg2              OUT VARCHAR2,
                                   x_seg3              OUT VARCHAR2,
                                   x_err_msg           OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT segment1, --             REPLACE (segment2, '&', 'and'),
                         --             REPLACE (segment3, '&', 'and')
                         TRANSLATE (segment2, '&', 'a'), TRANSLATE (segment3, '&', 'a') segment3
          INTO x_seg1, x_seg2, x_seg3
          FROM mtl_categories
         WHERE category_id = TRIM (pn_category_id) AND structure_id = 201;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_seg1      := NULL;
            x_seg2      := NULL;
            x_seg3      := NULL;
            x_err_msg   := SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END;

    FUNCTION get_ship_to_org_fnc (pn_line_loc_id   IN     NUMBER,
                                  x_err_msg           OUT VARCHAR2)
        RETURN NUMBER
    IS
        l_ship_to_org_id   po_line_locations_all.ship_to_organization_id%TYPE;
    BEGIN
        SELECT ship_to_organization_id
          INTO l_ship_to_org_id
          FROM po_line_locations_all
         WHERE line_location_id = pn_line_loc_id;

        RETURN l_ship_to_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_ship_to_org_id   := NULL;
            x_err_msg          := SUBSTR (SQLERRM, 1, 200);
            RETURN l_ship_to_org_id;
    END;

    FUNCTION get_item_tax_class_fnc (pn_line_loc_id IN NUMBER, pn_ship_to_organization_id IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_tax_class   mtl_categories.segment1%TYPE;
    BEGIN
        SELECT mc.segment1
          INTO lv_tax_class
          FROM mtl_categories mc, mtl_category_sets mcs, mtl_item_categories mic,
               po_lines_all pla, po_line_locations_all plla
         WHERE     mc.category_id = mic.category_id
               AND plla.line_location_id = pn_line_loc_id
               AND plla.po_line_id = pla.po_line_id
               AND mic.inventory_item_id = pla.item_id
               AND mic.organization_id = pn_ship_to_organization_id
               AND mic.category_set_id = mcs.category_set_id
               AND mcs.category_set_name = 'Tax Class';

        RETURN lv_tax_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_tax_class   := NULL;
            x_err_msg      := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_tax_class;
    END;

    FUNCTION get_natural_acc_fnc (pn_invoice_id IN NUMBER, pn_line_number IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_account   gl_code_combinations.segment6%TYPE;
    BEGIN
        -- Checking for Manual Invoice or Non PO Matched Invoice
        BEGIN
            SELECT DISTINCT segment6
              INTO lv_account
              FROM apps.gl_code_combinations gcc, apps.ap_invoice_lines_all aila
             WHERE     aila.invoice_id = pn_invoice_id
                   AND aila.line_number = pn_line_number
                   AND NVL (aila.attribute2, aila.default_dist_ccid) =
                       gcc.code_combination_id;

            RETURN lv_account;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                -- Check for PO Matched Invoice
                BEGIN
                    SELECT DISTINCT segment6
                      INTO lv_account
                      FROM apps.gl_code_combinations gcc, apps.ap_invoice_distributions_all aida
                     WHERE     aida.invoice_id = pn_invoice_id
                           AND aida.invoice_line_number = pn_line_number
                           AND aida.dist_code_combination_id =
                               gcc.code_combination_id;

                    RETURN lv_account;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_account   := NULL;
                        x_err_msg    := SUBSTR (SQLERRM, 1, 200);
                        RETURN lv_account;
                END;
            WHEN OTHERS
            THEN
                lv_account   := NULL;
                x_err_msg    := SUBSTR (SQLERRM, 1, 200);
                RETURN lv_account;
        END;

        RETURN lv_account;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_account   := NULL;
            x_err_msg    := SUBSTR (SQLERRM, 1, 200);
            RETURN lv_account;
    END;

    FUNCTION check_multi_period_flag_fnc (pn_invoice_id IN NUMBER, pn_line_number IN NUMBER, x_err_msg OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_def_flag         NUMBER := 0;
        ld_def_start_date   DATE := NULL;
    BEGIN
        SELECT COUNT (deferred_acctg_flag)
          INTO ln_def_flag
          FROM apps.ap_invoice_lines_all aila
         WHERE     aila.invoice_id = pn_invoice_id
               AND aila.line_number = pn_line_number
               AND NVL (deferred_acctg_flag, 'N') = 'Y';

        IF ln_def_flag > 0
        THEN
            BEGIN
                SELECT def_acctg_start_date
                  INTO ld_def_start_date
                  FROM apps.ap_invoice_lines_all
                 WHERE     invoice_id = pn_invoice_id
                       AND line_number = pn_line_number;

                RETURN 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_def_start_date   := NULL;
                    x_err_msg           := SUBSTR (SQLERRM, 1, 200);
                    RETURN 0;
            END;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_msg   := SUBSTR (SQLERRM, 1, 200);
            RETURN 0;
    END;

    PROCEDURE xxd_ap_sbx_pre_calc_prc (p_batch_id IN NUMBER)
    IS
        --PRAGMA AUTONOMOUS_TRANSACTION;

        -- Cursor to fetch all the AP related data from sabrix invoice
        CURSOR cur_ap_hdr_data IS
            SELECT aia.invoice_type_lookup_code,
                   aia.source,
                   aia.po_header_id,
                   aia.org_id,                     --- Added as per CCR0009257
                   REGEXP_SUBSTR (sbx_inv.external_company_id, '[^-]+', 1,
                                  2) ext_comp_id,   -- Added as per CCR0009257
                   sbx_inv.*
              FROM sabrix_invoice sbx_inv, apps.ap_invoices_all aia
             WHERE     1 = 1
                   AND calling_system_number = '200'
                   AND aia.invoice_id = sbx_inv.user_element_attribute41
                   AND aia.org_id = user_element_attribute45
                   AND sbx_inv.batch_id = p_batch_id;

        CURSOR cur_ap_line_data (pn_batch_id NUMBER, pn_invoice_id NUMBER)
        IS
            SELECT sbx_line.*
              FROM sabrix_line sbx_line
             WHERE     1 = 1
                   AND sbx_line.batch_id = pn_batch_id
                   AND sbx_line.invoice_id = pn_invoice_id;

        ln_category_id               mtl_categories.category_id%TYPE;
        lv_cat_seg1                  mtl_categories.segment1%TYPE;
        lv_cat_seg2                  mtl_categories.segment2%TYPE;
        lv_cat_seg3                  mtl_categories.segment3%TYPE;
        l_boolean                    BOOLEAN;
        ln_ship_to_organization_id   po_line_locations_all.ship_to_organization_id%TYPE;
        lv_item_tax_class            mtl_categories.segment1%TYPE;
        lv_natural_account           gl_code_combinations.segment6%TYPE;
        ln_multi_period_line         NUMBER;
        ln_po_line_loc_id            po_line_locations_all.line_location_id%TYPE;
        lv_primary_use               ap_invoice_lines_all.primary_intended_use%TYPE;
        lv_par_flex_val              VARCHAR2 (100);
        lv_multi_acct_flag           VARCHAR2 (1) := 'N';
        ln_invoice_id                ap_invoices_all.invoice_id%TYPE;
        lv_error_msg                 VARCHAR2 (4000);
        -- Added as per CCR0009257
        lv_ext_company_id            VARCHAR2 (100);
        lv_company_id                VARCHAR2 (10);
        ln_org_id                    NUMBER;
        ln_count                     NUMBER;
        -- End of Change
        lv_asset_flag                VARCHAR2 (10); -- Added as per CCR0009727
        lv_asset_value               VARCHAR2 (10); -- Added as per CCR0009727
    BEGIN
        lv_procedure   := 'XXD_AP_SBX_PRE_CALC_PRC';
        lv_location    := 'First Entry Point into AP';

        debug_prc (p_batch_id, lv_procedure, lv_location,
                   'Start of Data flow for AP');

        --      UPDATE sabrix_invoice
        --         SET username = '^SSUserDOC', password = 'Password1!'
        --       WHERE batch_id = p_batch_id;
        --
        --      COMMIT;

        --References used
        --sabrix invoice.user_element_attribute41 --> ap_invoice_id
        --sabrix invoice.user_element_attribute45 --> org_id

        -- Open the Cursor to fecth the Invoice

        FOR hdr IN cur_ap_hdr_data
        LOOP
            lv_error_msg        := NULL;
            ln_po_line_loc_id   := NULL;
            lv_primary_use      := NULL;
            lv_location         := 'AP Headers';

            -- Added as per CCR0009257
            lv_company_id       := NULL;
            lv_ext_company_id   := NULL;
            ln_org_id           := NULL;
            ln_count            := 0;
            -- End of Change for CCR0009257

            update_inv_prc (p_batch_id, hdr.user_element_attribute41);

            -- Get Invoice type, If Invoice is Prepayment, update invoice table as below

            /*IF hdr.invoice_type_lookup_code = 'PREPAYMENT'
            THEN
               debug_prc (
                  p_batch_id,
                  lv_procedure,
                  lv_location,
                     'Invoice type should be PREPAY  - '
                  || hdr.invoice_type_lookup_code);

               UPDATE sabrix_invoice
                  SET user_element_attribute1 = 'PREPAYMENT'
                WHERE     batch_id = hdr.batch_id
                      AND user_element_attribute41 =
                             hdr.user_element_attribute41
                      AND user_element_attribute45 =
                             hdr.user_element_attribute45;
            END IF;

            -- Get the Invoice Source,If it is Expense, update as below

            IF hdr.source = 'CONCUR'
            THEN
               debug_prc (
                  p_batch_id,
                  lv_procedure,
                  lv_location,
                     'Invoice Source should be Concur and value is  - '
                  || hdr.source);

               UPDATE sabrix_invoice
                  SET user_element_attribute2 = 'EXPENSE'
                WHERE     batch_id = hdr.batch_id
                      AND user_element_attribute41 =
                             hdr.user_element_attribute41
                      AND user_element_attribute45 =
                             hdr.user_element_attribute45;
            END IF;

            IF hdr.source = 'LUCERNEX'
            THEN
               debug_prc (
                  p_batch_id,
                  lv_procedure,
                  lv_location,
                  'Invoice Source should be LCX and value is  - ' || hdr.source);

               UPDATE sabrix_invoice
                  SET user_element_attribute2 = 'LUCERNEX'
                WHERE     batch_id = hdr.batch_id
                      AND user_element_attribute41 =
                             hdr.user_element_attribute41
                      AND user_element_attribute45 =
                             hdr.user_element_attribute45;
            END IF; */

            --         UPDATE sabrix_invoice
            --            SET user_element_attribute1 = hdr.invoice_type_lookup_code,
            --                user_element_attribute2 = hdr.source
            --          WHERE     batch_id = hdr.batch_id
            --                AND user_element_attribute41 = hdr.user_element_attribute41;
            --AND user_element_attribute45 = hdr.user_element_attribute45;

            /*
            BEGIN

            SELECT  fnd_global.ORG_ID
                        INTO  ln_org_id from dual;
            EXCEPTION
            WHEN OTHERS
            THEN
               ln_org_id := -1;
            END; */

            debug_prc (p_batch_id,
                       'Get_Org_ID',
                       'Get_Org_ID',
                          'Get_Org_ID - '
                       || ln_org_id
                       || 'External Company ID - '
                       || hdr.external_company_id
                       || 'and Substr1 Value is - '
                       || REGEXP_SUBSTR (hdr.external_company_id, '[^-]+', 1,
                                         2)
                       || 'and Substr2 Value is - '
                       || REGEXP_SUBSTR (hdr.external_company_id, '[^-]+', 1,
                                         2));

            /*
            IF ln_org_id = '-1'
            THEN
               ln_count := 0;
            ELSE
               ln_count := 1;
            END IF;
            */


            IF hdr.ext_comp_id IS NULL
            THEN
                ln_count   := 1;
            END IF;



            IF ln_count = 1
            THEN
                BEGIN
                    SELECT fpov.profile_option_value
                      INTO lv_company_id
                      FROM fnd_profile_option_values fpov, fnd_profile_options fpo
                     WHERE     fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.profile_option_name = 'SABRIX_COMPANY'
                           AND fpov.level_id = 10006
                           AND fpov.level_value = hdr.org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_company_id   := NULL;
                END;


                IF lv_company_id IS NOT NULL
                THEN
                    lv_ext_company_id   := gv_host || lv_company_id;
                ELSE
                    lv_ext_company_id   := NULL;
                END IF;

                debug_prc (
                    p_batch_id,
                    'Get_Ext_Comp',
                    'Get_Ext_Comp',
                       ' lv_ext_company_id  - '
                    || lv_ext_company_id
                    || ' - gv_host is - '
                    || gv_host
                    || ' - lv_company_id is - '
                    || lv_company_id);


                update_header_prc (
                    p_batch_id                  => hdr.batch_id,
                    p_header_id                 => hdr.user_element_attribute41,
                    p_calling_system_number     => hdr.calling_system_number, -- Added as per CCR0009257
                    p_user_element_attribute1   =>
                        hdr.invoice_type_lookup_code,
                    p_user_element_attribute2   => hdr.source,
                    p_ext_company_id            => lv_ext_company_id --- Added as per CCR0009257
                                                                    );
            ELSE
                -- Added as per CCR0009257

                update_header_prc (
                    p_batch_id                  => hdr.batch_id,
                    p_header_id                 => hdr.user_element_attribute41,
                    p_user_element_attribute1   =>
                        hdr.invoice_type_lookup_code,
                    p_calling_system_number     => 2000, -- Added as per CCR0009257
                    p_user_element_attribute2   => hdr.source,
                    p_ext_company_id            => NULL);
            -- End of Change
            END IF;


            IF    NVL (hdr.source, 'A') <> 'CONCUR'
               OR NVL (hdr.invoice_type_lookup_code, 'A') <> 'PREPAYMENT'
            THEN
                -- Check whether the Invoice IS PO Matched

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       ' Invoice Source is  - '
                    || hdr.source
                    || ' - and invoice type lookup code is - '
                    || hdr.invoice_type_lookup_code);


                IF hdr.po_header_id IS NOT NULL
                THEN
                    lv_error_msg     := NULL;
                    ln_category_id   := NULL;

                    --fetch the values of PO category and Segment Values

                    ln_category_id   :=
                        get_po_category_fnc (hdr.po_header_id,
                                             NULL,
                                             lv_error_msg);

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Category ID fetched at Header level is  - '
                        || ln_category_id
                        || ' Exception if exists is   - '
                        || lv_error_msg);


                    IF ln_category_id IS NOT NULL
                    THEN
                        l_boolean      := NULL;
                        lv_cat_seg1    := NULL;
                        lv_cat_seg2    := NULL;
                        lv_cat_seg3    := NULL;
                        lv_error_msg   := NULL;
                        -- As PO category is not null, then the PO Category segments as required
                        l_boolean      :=
                            get_category_seg_fnc (
                                pn_category_id   => ln_category_id,
                                x_seg1           => lv_cat_seg1,
                                x_seg2           => lv_cat_seg2,
                                x_seg3           => lv_cat_seg3,
                                x_err_msg        => lv_error_msg);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Value Derived are Seg1  - '
                            || lv_cat_seg1
                            || ' Value Derived are Seg2  - '
                            || lv_cat_seg2
                            || ' Value Derived are Seg3  - '
                            || lv_cat_seg3
                            || ' Exception if exists is   - '
                            || lv_error_msg);
                    END IF;
                END IF;


                -- Now Open the Sabrix Invoice Lines table to proceed

                FOR line IN cur_ap_line_data (hdr.batch_id, hdr.invoice_id)
                LOOP
                    lv_location                  := 'Inside PO LINES';

                    ln_ship_to_organization_id   := NULL;
                    lv_item_tax_class            := NULL;
                    ln_category_id               := NULL;
                    lv_cat_seg1                  := NULL;
                    lv_cat_seg2                  := NULL;
                    lv_cat_seg3                  := NULL;
                    lv_natural_account           := NULL;
                    ln_multi_period_line         := 0;
                    l_boolean                    := NULL;
                    ln_po_line_loc_id            := NULL;
                    lv_multi_acct_flag           := 'N';
                    ln_invoice_id                := NULL;
                    lv_error_msg                 := NULL;
                    lv_asset_flag                := NULL; -- Added as per CCR0009727
                    lv_asset_value               := NULL; -- Added as per CCR0009727

                    -- Now check whether line level there is any PO
                    -- User_Element_Attribute45 line level will have line_location_id for PO MATCHED Invoices

                    -- Get the po_line_location_id based on AP Invoice Lines All

                    BEGIN
                        SELECT po_line_location_id, aila.invoice_id, aila.assets_tracking_flag -- Added as per CCR0009727
                          INTO ln_po_line_loc_id, ln_invoice_id, lv_asset_flag -- Added as per CCR0009727
                          FROM ap_invoices_all aia, ap_invoice_lines_all aila
                         WHERE     1 = 1
                               AND aia.invoice_id = aila.invoice_id
                               AND aia.invoice_id =
                                   hdr.user_element_attribute41
                               AND aila.line_number =
                                   line.user_element_attribute41;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_po_line_loc_id   := NULL;
                            lv_asset_flag       := NULL; --- Added as per CCR0009727
                            lv_error_msg        := SUBSTR (SQLERRM, 1, 200);
                    END;

                    --- Added as per CCR0009727


                    IF NVL (lv_asset_flag, 'N') = 'N'
                    THEN
                        BEGIN
                            SELECT assets_tracking_flag
                              INTO lv_asset_flag
                              FROM apps.ap_invoice_distributions_all
                             WHERE     1 = 1
                                   AND invoice_id =
                                       hdr.user_element_attribute41
                                   AND invoice_line_number =
                                       line.user_element_attribute41
                                   AND assets_tracking_flag IS NOT NULL
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_asset_flag   := NULL;
                        END;
                    END IF;


                    lv_asset_value               := NULL;

                    BEGIN
                        SELECT DECODE (lv_asset_flag, 'Y', 'ASSET')
                          INTO lv_asset_value
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_asset_value   := NULL;
                    END;

                    --- End of Change as per CCR0009727

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Value Derived for line location id   - '
                        || ln_po_line_loc_id
                        || ' Invoice ID  - '
                        || hdr.user_element_attribute41
                        || ' Inv Line Num  - '
                        || line.user_element_attribute41
                        || ' Exception if exists is   - '
                        || lv_error_msg);

                    IF ln_po_line_loc_id IS NOT NULL
                    THEN
                        ln_category_id   := NULL;
                        lv_error_msg     := NULL;
                        ln_category_id   :=
                            get_po_category_fnc (NULL,
                                                 ln_po_line_loc_id,
                                                 lv_error_msg);

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' Category ID fetched at line level is  - '
                            || ln_category_id
                            || ' Exception if exists is   - '
                            || lv_error_msg);


                        IF ln_category_id IS NOT NULL
                        THEN
                            l_boolean      := NULL;
                            lv_cat_seg1    := NULL;
                            lv_cat_seg2    := NULL;
                            lv_cat_seg3    := NULL;
                            lv_error_msg   := NULL;
                            -- As PO category is not null, then the PO Category segments as required
                            l_boolean      :=
                                get_category_seg_fnc (
                                    pn_category_id   => ln_category_id,
                                    x_seg1           => lv_cat_seg1,
                                    x_seg2           => lv_cat_seg2,
                                    x_seg3           => lv_cat_seg3,
                                    x_err_msg        => lv_error_msg);

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Line Value Derived are Seg1  - '
                                || lv_cat_seg1
                                || ' Value Derived are Seg2  - '
                                || lv_cat_seg2
                                || ' Value Derived are Seg3  - '
                                || lv_cat_seg3
                                || ' Exception if exists is   - '
                                || lv_error_msg);
                        ELSIF ln_category_id IS NULL
                        THEN
                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Category ID derived is NULL  - '
                                || ln_category_id); -- When PO Category is derived as NULL through PO line location
                        -- Add logs to capture the error message
                        END IF;

                        -- Trade PO, there is a chance that this can have Inventory item associated

                        IF lv_cat_seg1 = 'Trade'
                        THEN
                            lv_location                  :=
                                'Trade Segment Ship Org and Tax Class';
                            lv_error_msg                 := NULL;
                            ln_ship_to_organization_id   :=
                                get_ship_to_org_fnc (ln_po_line_loc_id,
                                                     lv_error_msg);

                            debug_prc (
                                p_batch_id,
                                lv_procedure,
                                lv_location,
                                   ' Derived ln_ship_to_organization_id is  - '
                                || ln_ship_to_organization_id
                                || ' for PO Line Location ID  - '
                                || ln_po_line_loc_id
                                || ' Exception if exists is   - '
                                || lv_error_msg);

                            lv_error_msg                 := NULL;
                            lv_item_tax_class            :=
                                get_item_tax_class_fnc (
                                    ln_po_line_loc_id,
                                    ln_ship_to_organization_id,
                                    lv_error_msg);
                        ELSE
                            -- No need to calculate any tax class as Non Trade Categories doesn't have any item associated
                            NULL;
                        END IF;

                        debug_prc (
                            p_batch_id,
                            lv_procedure,
                            lv_location,
                               ' For Trade Segment value does matter else ignore  - '
                            || lv_cat_seg1
                            || ' ln_ship_to_organization_id - '
                            || ln_ship_to_organization_id
                            || ' lv_item_tax_class - '
                            || lv_item_tax_class);
                    END IF;

                    -- Getting Expense account is common accross Manual and PO Matched Invoices
                    lv_location                  := 'Get Natural Account';
                    lv_error_msg                 := NULL;
                    lv_natural_account           :=
                        get_natural_acc_fnc (hdr.user_element_attribute41,
                                             line.User_Element_Attribute41,
                                             lv_error_msg);

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Derived Natural Account is  - '
                        || lv_natural_account
                        || ' For user_element_attribute41  - '
                        || hdr.user_element_attribute41
                        || ' For line user_element_attribute41  - '
                        || line.User_Element_Attribute41
                        || ' Exception if exists is   - '
                        || lv_error_msg);

                    -- Override DFF is replaced by Primary intended use column

                    lv_location                  := 'Primary Intended Usage';
                    lv_primary_use               := NULL;
                    lv_error_msg                 := NULL;

                    BEGIN
                        SELECT primary_intended_use
                          INTO lv_primary_use
                          FROM apps.ap_invoice_lines_all
                         WHERE     invoice_id = hdr.user_element_attribute41
                               AND line_number =
                                   line.User_Element_Attribute41;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_primary_use   := NULL;
                            lv_error_msg     := SUBSTR (SQLERRM, 1, 200);
                    END;

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Derived Primary Intended Usage is  - '
                        || lv_primary_use
                        || ' For user_element_attribute41  - '
                        || hdr.user_element_attribute41
                        || ' For line user_element_attribute41  - '
                        || line.User_Element_Attribute41
                        || ' Exception if exists is   - '
                        || lv_error_msg);

                    -- Getting Multiperiod accounting invoice lines and updating
                    -- Multi line Accounting is to fetch the regular account at distr. not SLA Account
                    -- Tax doesn't need to be Calculated on Final Accounting, its to be actual deferred account
                    -- value based on XXDO_AP_PREPAID_ACC_DVS

                    /*lv_error_msg := NULL;
                    ln_multi_period_line := 0;

                    ln_multi_period_line :=
                                     check_multi_period_flag_fnc (ln_invoice_id,
                                                                  line.User_Element_Attribute41,
                                                                  lv_error_msg);

                   -- Multiline is only applicable for Non PO Matched Invoices

                   lv_par_flex_val := NULL;
                   lv_multi_acct_flag := 'N';
                   lv_location := 'Multi Line Acctng Flag';

                   IF     ln_multi_period_line > 0
                      AND lv_natural_account IS NOT NULL
                      AND ln_po_line_loc_id IS NULL
                   THEN
                      BEGIN

                         lv_multi_acct_flag := 'Y';

                         SELECT PARENT_FLEX_VALUE_LOW
                           INTO lv_par_flex_val
                           FROM (SELECT ffv.flex_value, ffv.parent_flex_value_low
                                   FROM apps.fnd_flex_value_sets ffvs,
                                        apps.fnd_flex_values ffv
                                  WHERE     ffvs.flex_value_set_name =
                                               'XXDO_AP_PREPAID_ACC_DVS'
                                        AND ffvs.flex_Value_Set_id =
                                               ffv.flex_value_set_id
                                        AND ffv.enabled_flag = 'Y'
                                        AND SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE+1))
                          WHERE FLEX_VALUE = lv_natural_account;
                      EXCEPTION
                         WHEN OTHERS
                         THEN
                            lv_par_flex_val := NULL;
                      END;
                   END IF;

                   debug_prc (
                      p_batch_id,
                      lv_procedure,
                      lv_location,
                         'Mult line Acctg flag is - '
                      || lv_multi_acct_flag
                      || ' - with Natural account as - '
                      || lv_natural_account
                      || ' - with Deferred account as - '
                      || lv_par_flex_val);

                      IF lv_multi_acct_flag = 'Y'
                      THEN
                        lv_natural_account :=  lv_par_flex_val;
                      END IF; */

                    -- End of Change for CCR0009727

                    /*UPDATE sabrix_line
                       SET user_element_attribute1 = lv_cat_seg1,
                           user_element_attribute2 =
                              DECODE (
                                 lv_cat_seg1,
                                 'Trade', '',
                                    lv_cat_seg2
                                 || DECODE (lv_cat_seg1,
                                            'Trade', '',
                                            'Non-Trade', '.',
                                            '')
                                 || lv_cat_seg3),
                           user_element_attribute3 =          --lv_natural_account,
                              DECODE (lv_multi_acct_flag,
                                      'N', lv_natural_account,
                                      lv_par_flex_val),
                           user_element_attribute4 = lv_item_tax_class,
                           user_element_attribute5 = lv_primary_use,
                           user_element_attribute6 =
                              DECODE (lv_cat_seg1, 'Trade', '', lv_cat_seg2),
                           user_element_attribute7 =
                              DECODE (lv_cat_seg1, 'Trade', '', lv_cat_seg3),
                           transaction_type = 'GS'
                     WHERE     invoice_id = line.invoice_id
                           AND user_element_attribute41 =
                                  line.user_element_attribute41;*/

                    --               UPDATE sabrix_line
                    --                  SET user_element_attribute1 = lv_cat_seg1,
                    --                      user_element_attribute2 =
                    --                         lv_cat_seg2 || '.' || lv_cat_seg3,
                    --                      user_element_attribute3 = lv_natural_account,
                    --                      --                      user_element_attribute3 =          --lv_natural_account,
                    --                      --                         DECODE (lv_multi_acct_flag,
                    --                      --                                 'N', lv_natural_account,
                    --                      --                                 lv_par_flex_val),
                    --                      user_element_attribute4 = lv_item_tax_class,
                    --                      user_element_attribute5 = lv_primary_use,
                    --                      user_element_attribute6 = lv_cat_seg2,
                    --                      user_element_attribute7 = lv_cat_seg3,
                    --                      transaction_type = 'GS'
                    --                WHERE     invoice_id = line.invoice_id
                    --                      AND user_element_attribute41 =
                    --                             line.user_element_attribute41
                    --                      AND batch_id = line.batch_id;

                    update_line_prc (
                        p_batch_id                   => line.batch_id,
                        p_inv_id                     => line.invoice_id,
                        p_line_id                    => line.user_element_attribute41,
                        p_user_element_attribute1    => lv_cat_seg1,
                        p_user_element_attribute2    =>
                            lv_cat_seg2 || '.' || lv_cat_seg3,
                        p_user_element_attribute3    => lv_natural_account,
                        p_user_element_attribute4    => lv_item_tax_class,
                        p_user_element_attribute5    => lv_primary_use,
                        p_user_element_attribute6    => lv_cat_seg2,
                        p_user_element_attribute7    => lv_cat_seg3,
                        p_user_element_attribute11   => lv_asset_value, --- Added as per CCR0009727
                        p_transaction_type           => 'GS');
                END LOOP;
            END IF;
        --update_inv_prc (p_batch_id, hdr.user_element_attribute41);
        END LOOP;
    END xxd_ap_sbx_pre_calc_prc;

    -- Start of Change for CCR0009031

    FUNCTION bypass_tax_fnc (p_event_class_code IN VARCHAR2, p_appl_id IN NUMBER, p_entity_code IN VARCHAR2
                             , p_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_po_count    NUMBER;
        ln_req_count   NUMBER;
        lv_location    VARCHAR2 (500);
        lv_procedure   VARCHAR2 (500);
    BEGIN
        ln_po_count    := 0;
        ln_req_count   := 0;
        lv_location    := 'Bypass Tax FNC';
        lv_procedure   := 'BYPASS_TAX_FNC';


        IF p_appl_id = 201 AND p_entity_code = 'PURCHASE_ORDER'
        THEN
            -- Check whether the requisition is Trade Requisition

            BEGIN
                SELECT COUNT (1)
                  INTO ln_po_count
                  FROM apps.po_headers_all pha
                 WHERE     pha.po_header_id = p_trx_id
                       AND EXISTS
                               (SELECT mc.segment1
                                  FROM mtl_categories mc, po_lines_all pla
                                 WHERE     1 = 1
                                       AND mc.category_id = pla.category_id
                                       AND mc.segment1 = 'Trade'
                                       AND pla.po_header_id =
                                           pha.po_header_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_po_count   := 0;
            END;

            debug_prc (
                p_trx_id,
                lv_procedure,
                lv_location,
                   ' Entity Code is - '
                || p_entity_code
                || ' For po_header_id  - '
                || p_trx_id
                || ' PO Count is   - '
                || ln_po_count);

            IF ln_po_count = 1
            THEN
                RETURN 1;
            ELSE
                RETURN 2;
            END IF;
        ELSIF p_appl_id = 201 AND p_entity_code = 'REQUISITION'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_req_count
                  FROM apps.po_requisition_headers_all prha
                 WHERE     prha.requisition_header_id = p_trx_id
                       AND EXISTS
                               (SELECT mc.segment1
                                  FROM mtl_categories mc, po_requisition_lines_all prla
                                 WHERE     1 = 1
                                       AND mc.category_id = prla.category_id
                                       AND mc.segment1 = 'Trade'
                                       AND prla.requisition_header_id =
                                           prha.requisition_header_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_req_count   := 0;
            END;

            debug_prc (
                p_trx_id,
                lv_procedure,
                lv_location,
                   ' Entity Code is - '
                || p_entity_code
                || ' For requisition_header_id  - '
                || p_trx_id
                || ' Req Count is   - '
                || ln_po_count);


            IF ln_po_count = 1
            THEN
                RETURN 1;
            ELSE
                RETURN 2;
            END IF;
        ELSE
            RETURN 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 2;
    END bypass_tax_fnc;

    -- End of Change for CCR0009031


    PROCEDURE xxd_p2p_sbx_post_calc_prc (p_batch_id IN NUMBER)
    IS
        --      PRAGMA AUTONOMOUS_TRANSACTION;

        ln_value       NUMBER := 0;
        ln_tot_value   NUMBER := 0;

        -- Start of Change for CCR0009031

        CURSOR get_inv_inf IS
              SELECT aia.invoice_amount,
                     aia.invoice_id,
                     aia.org_id,
                     (SELECT SUM (amount)
                        FROM apps.ap_invoice_lines_all aila
                       WHERE     1 = 1
                             AND aila.invoice_id = aia.invoice_id
                             AND aila.line_type_lookup_code = 'ITEM') line_amount
                FROM apps.ap_invoices_all aia, apps.sabrix_invoice si
               WHERE     si.user_element_attribute41 = aia.invoice_id
                     AND si.user_element_attribute45 = aia.org_id
                     AND si.batch_id = p_batch_id
                     AND si.calling_system_number = '200'
            GROUP BY aia.invoice_amount, aia.invoice_id, aia.org_id;

        CURSOR get_tax_amt (pn_invoice_id NUMBER, pn_org_id NUMBER)
        IS
            SELECT SUM (ltx.tax_amount) tax_amount, SUM (ltx.authority_amount)
              FROM sabrix_line_tax ltx, sabrix_invoice si
             WHERE     ltx.batch_id = p_batch_id -- You should have a batch id, pass that to the function
                   AND si.batch_id = ltx.batch_id
                   AND si.invoice_id = ltx.invoice_id
                   AND si.calling_system_number = '200'
                   AND si.user_element_attribute41 = pn_invoice_id
                   AND si.user_element_attribute45 = pn_org_id;
    -- End of Change for CCR0009031

    BEGIN
        -- For transactions with recoverability of Reverse Charge Tax: The solution must convert reverse charge output tax lines to recoverable

        lv_procedure   := 'XXD_P2P_SBX_POST_CALC_PRC';
        lv_location    := 'POST CALC TASK';


        debug_prc (p_batch_id, lv_procedure, lv_location,
                   'Start of Post Calc Process');

        -- Start of Change for CCR0009031

        ln_value       := 0;
        ln_tot_value   := 0;


        BEGIN
            FOR inv IN get_inv_inf
            LOOP
                ln_tot_value   := 0;

                -- get the OU based Tolerance Limit

                BEGIN
                    SELECT ffvl.attribute2
                      INTO ln_tot_value
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AP_INV_TAX_OU_TOL_VS'
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)
                           AND ffvl.attribute1 = inv.org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_tot_value   := 0;
                END;

                debug_prc (
                    p_batch_id,
                    lv_procedure,
                    lv_location,
                       ' The Value of Tolerance is - '
                    || ln_tot_value
                    || ' - for Org ID - '
                    || inv.org_id);

                IF NVL (
                       ABS (
                             NVL (inv.invoice_amount, 0)
                           - NVL (inv.line_amount, 0)),
                       0) <>
                   0
                THEN
                    FOR tax IN get_tax_amt (inv.invoice_id, inv.org_id)
                    LOOP
                        IF NVL (
                               ABS (
                                   inv.invoice_amount - inv.line_amount - tax.tax_amount),
                               0) <=
                           ln_tot_value
                        THEN
                            ln_value   :=
                                  inv.invoice_amount
                                - inv.line_amount
                                - tax.tax_amount;
                        ELSE
                            ln_value   := 0;
                        END IF;

                        UPDATE Sabrix_Line_Tax
                           SET tax_amount   = tax_amount + ln_value
                         WHERE     batch_id = p_batch_id
                               AND invoice_id = 1
                               AND line_id = 1;
                    END LOOP;

                    debug_prc (
                        p_batch_id,
                        lv_procedure,
                        lv_location,
                           ' Invoice amount and Line Amount is not Equal and Value to be added is  - '
                        || ln_value
                        || ' - for Invoice ID - '
                        || inv.invoice_id);
                END IF;
            END LOOP;
        END;

        --- End of Change for CCR0009031

        UPDATE Sabrix_Line_Tax
           SET batch_id   = batch_id * -1
         WHERE erp_tax_code = 'SUPPRESS' AND batch_id = p_batch_id;

        UPDATE sabrix_line_tax sil
           SET sil.input_recovery_percent = 1, sil.input_recovery_amount = tax_amount
         WHERE                         --SABRIX_INVOICE_OUT.COMPANY_ROLE = 'B'
                   sil.tax_direction = 'O'
               AND sil.batch_id = p_batch_id
               AND EXISTS
                       (SELECT 1
                          FROM sabrix_invoice_out sio
                         WHERE     sio.batch_id = sil.batch_id
                               AND sio.invoice_id = sil.invoice_id
                               AND sio.company_role = 'B');

        -- For transactions with foreign VAT implications

        UPDATE sabrix_line_tax
           SET input_recovery_percent = '0', input_recovery_amount = '0'
         WHERE erp_tax_code = 'Foreign Tax' AND batch_id = p_batch_id;
    -- Suppress tax line: ONESOURCE will occasionally return excess tax lines that do not need to be imported into Oracle. These needs to be suppressed in the integration

    -- COMMIT;

    END xxd_p2p_sbx_post_calc_prc;
END XXD_SBX_P2P_INT_PKG;
/
