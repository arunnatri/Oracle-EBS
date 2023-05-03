--
-- XXDO_EDI_UTILS_PUB  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_EDI_UTILS_PUB"
AS
    /*********************************************************************************************
      Important Notes :  This Package needs WF bounce after compilation.
      Modification history:
     *********************************************************************************************

        Version        Date        Author             Description
       ---------  -----------     ------------     ------------------------------------
         1.0                                             Initial Version.
         2.0        26-MAY-2015     INFOSYS              Modified to update the responsibility name as per BTUAT.
         3.0        09-JUN-2015     INFOSYS              Modified to fetch correct site use id
         4.0        16-JUN-2015     B.T.Team             Corrected a column query in edi_order_book_event Function
         5.0        09-AUG-2015     INFOSYS              EDI All order split CR
         6.0        16-SEP-2015     INFOSYS              Order Hold OU fix
         7.0        06-NOV-2015     INFOSYS              Defect#200
         8.0        10-SEP-2015     INFOSYS              Pricing Agreement  ( PA ) issues - INC0313041 (Bill-To location for Order type rather than Ship-to)
         9.0        08-FEB-2017     INFOSYS              Commented the Commit portion after the Hold API as part of the CCR0005906
         10.0       01-DEC-2017     INFOSYS              CCR0006735 - EDI 855 restrict customers
         11.0       06-JUN-2018     INFOSYS              CCR0007315 - EDI 855 Changes
         12.0       27-Nov-2018     Gaurav Joshi         CCR0007582 - EBS:O2F: Order Import Defects
         13.0       02-Feb-2019     Gaurav Joshi         CCR0007713 -Ability to turn off EDI 855 for specific customer and order type combination
         14.0       04-Oct-2019     Viswanathan Pandian  Updated for CCR0008173
         15.0       13-Jul-2020     Shivanshu Talwar     EDI Project -855 Changes and perfromance fix (CCR0008488)
         16.0       10-Nov-2020     Viswanathan Pandian  Updated for CCR0009023
         16.1       18-Mar-2021     Jayarajan A K        Modified for CCR0008870 - Global Inventory Allocation Project
      17.0       08-Dec-2021     Shivanshu            Modified for CCR0009477 - Shopify ASN
      17.1       12-Apr-2022     Jayarajan A K        CCR0009908: Some Orders showing "Created by" as Batch instead of the User
      18.0       12-Sep-2022     Shivanshu            CCR0010110 : Brand SKU Mismatch
         19.0       01-Sep-2022     Laltu Sah             Modified for CCR0010148
         *********************************************************************************************/
    lg_package_name                CONSTANT VARCHAR2 (200) := 'APPS.XXDO_EDI_UTILS_PUB';
    g_def_sub_xfer_trans_type_id   CONSTANT NUMBER := 2;
    g_mail_debugging_p                      VARCHAR2 (1)
        := SUBSTR (
               NVL (apps.do_get_profile_value ('DO_EDI_MAIL_DEBUG'), 'N'),
               1,
               1);
    g_mail_debug_attach_debug_p             VARCHAR2 (1)
        := SUBSTR (
               NVL (apps.do_get_profile_value ('DO_EDI_MAIL_DEBUG_DETAIL'),
                    'N'),
               1,
               1);
    g_n_temp                                NUMBER;
    --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
    gn_user_id                              NUMBER;
    gn_user_id1                             NUMBER;
    gn_resp_id                              NUMBER;
    gn_appln_id                             NUMBER;
    --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
    gv_op_unit                              VARCHAR2 (200)
                                                := 'Deckers eCommerce OU';
    g_op_unit                               VARCHAR2 (200);
    --W.r.t Version 5.0
    /* Private Types */

    /* Private Variables */
    l_api_version_number                    NUMBER := 1.0;
    l_commit                                VARCHAR2 (1) := fnd_api.g_false;
    c_debugging                             BOOLEAN := TRUE;
    l_buffer_number                         NUMBER;
    --  get the resp id from the session and use whereever required instead of using the hardcode resp id.
    g_resp_id                               NUMBER
        := fnd_profile.VALUE ('RESP_ID'); -- ADDED for CCR0007582 - EBS:O2F: Order Import Defects


    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO custom.do_debug (created_by, application_id, debug_text,
                                     session_id, call_stack)
                 VALUES (NVL (fnd_global.user_id, -1),
                         app,
                         msg,
                         USERENV ('SESSIONID'),
                         SUBSTR (DBMS_UTILITY.format_call_stack, 1, 2000));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    FUNCTION check_sps_customer (p_customer_number IN VARCHAR2)
        RETURN VARCHAR2                             --Start W.r.t Version 15.0
    IS
        lv_sps_customer   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            SELECT NVL (flv.attribute1, 'N')
              INTO lv_sps_customer
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                   AND flv.language = 'US'
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND NVL (TRUNC (flv.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND p_customer_number = flv.lookup_code;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The customer service is:'
                || lv_sps_customer
                || '-'
                || 'for customer');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sps_customer   := NULL;
        END;

        RETURN lv_sps_customer;
    END check_sps_customer;                           --End W.r.t Version 15.0


    PROCEDURE write_to_855_table (x_order_number NUMBER, x_customer_po_number VARCHAR2, x_acct_num VARCHAR2
                                  , lv_party_name VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_sps_customer   VARCHAR2 (10) := NULL;
    BEGIN
        lv_sps_customer   := check_sps_customer (x_acct_num); --W.r.t Version 15.0

        IF lv_sps_customer = 'N'                          --W.r.t Version 15.0
        THEN
            INSERT INTO xxdo.xxd_edi_855_order_process (order_number,
                                                        cust_po_number,
                                                        account_number,
                                                        customer_name,
                                                        process_status,
                                                        bulk_order_flag,
                                                        creation_date,
                                                        last_update_date)
                 VALUES (x_order_number, x_customer_po_number, x_acct_num,
                         lv_party_name, NULL, NULL,
                         SYSDATE, SYSDATE);
        ELSE                                              --W.r.t Version 15.0
            INSERT INTO xxdo.xxd_edi_855_sps_order_process (order_number,
                                                            cust_po_number,
                                                            account_number,
                                                            customer_name,
                                                            process_status,
                                                            bulk_order_flag,
                                                            creation_date,
                                                            last_update_date)
                 VALUES (x_order_number, x_customer_po_number, x_acct_num,
                         lv_party_name, NULL, NULL,
                         SYSDATE, SYSDATE);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    FUNCTION g_mail_debugging
        RETURN BOOLEAN
    IS
        l_proc_name   VARCHAR2 (240) := 'G_MAIL_DEBUGGING';
    BEGIN
        IF g_mail_debugging_p = 'Y'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END;

    FUNCTION g_mail_debugging_attach_debug
        RETURN BOOLEAN
    IS
        l_proc_name   VARCHAR2 (240) := 'G_MAIL_DEBUGGING_ATTACH_DEBUG';
    BEGIN
        IF g_mail_debug_attach_debug_p = 'Y'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END;

    PROCEDURE msg (p_message VARCHAR2, p_severity NUMBER:= 10000)
    IS
        l_proc_name   VARCHAR2 (240) := 'MSG';
    BEGIN
        do_debug_tools.msg (p_message, p_severity);
    END;

    PROCEDURE msg (p_module     VARCHAR2,
                   p_message    VARCHAR2,
                   p_severity   NUMBER:= 10000)
    IS
        l_proc_name   VARCHAR2 (240) := 'MSG';
    BEGIN
        do_debug_tools.msg (p_message, p_severity);
    END;

    PROCEDURE start_debugging
    IS
        l_proc_name   VARCHAR2 (240) := 'START_DEBUGGING';
    BEGIN
        do_debug_tools.start_debugging;
        do_debug_tools.enable_pipe;
    END;

    PROCEDURE stop_debugging
    IS
        l_proc_name   VARCHAR2 (240) := 'STOP_DEBUGGING';
    BEGIN
        do_debug_tools.stop_debugging;
    END;

    PROCEDURE m_start (l_title VARCHAR2)
    IS
        l_proc_name         VARCHAR2 (240) := 'M_START';
        v_def_mail_recips   do_mail_utils.tbl_recips;
        iretval             VARCHAR2 (4000);
    BEGIN
        v_def_mail_recips.delete;
        --V_DEF_MAIL_RECIPS (1) := 'bburns@deckers.com';
        v_def_mail_recips (1)   := 'brianb@deckers.com';     -- Changed for BT
        v_def_mail_recips (4)   := 'kgates@deckers.com';
        do_mail_utils.send_mail_header ('WCS_INTERFACE@deckers.com', v_def_mail_recips, l_title || '  --  ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                        , iretval);
        do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            iretval);
        do_mail_utils.send_mail_line ('--boundarystring', iretval);
        do_mail_utils.send_mail_line ('Content-Type: text/plain', iretval);
        do_mail_utils.send_mail_line ('', iretval);
    END;

    PROCEDURE m_msg (l_text VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (240) := 'M_MSG';
        iretval       VARCHAR2 (4000);
    BEGIN
        do_mail_utils.send_mail_line (l_text, iretval);
    END;

    PROCEDURE m_end
    IS
        l_proc_name   VARCHAR2 (240) := 'M_END';
        iretval       VARCHAR2 (4000);
    BEGIN
        SELECT COUNT (*)
          INTO g_n_temp
          FROM custom.do_debug
         WHERE session_id = USERENV ('SESSIONID');

        IF g_n_temp > 0 AND g_mail_debugging_attach_debug
        THEN
            m_msg ('--boundarystring');
            m_msg ('Content-Type: text/xls');
            m_msg (
                'Content-Disposition: attachment; filename="debug_information.xls"');
            m_msg ('');
            m_msg (
                   'Debug Text'
                || CHR (9)
                || 'Creation Date'
                || CHR (9)
                || 'Session ID'
                || CHR (9)
                || 'Debug ID'
                || CHR (9)
                || 'Call Stack');

            FOR debug_line IN (  SELECT *
                                   FROM custom.do_debug
                                  WHERE session_id = USERENV ('SESSIONID')
                               ORDER BY debug_id ASC)
            LOOP
                m_msg (
                       ''''
                    || REPLACE (debug_line.debug_text, CHR (9), ' ')
                    || CHR (9)
                    || TO_CHAR (debug_line.creation_date,
                                'MM/DD/YYYY HH:MI:SS AM')
                    || CHR (9)
                    || debug_line.session_id
                    || CHR (9)
                    || debug_line.debug_id
                    || CHR (9)
                    || REPLACE (SUBSTR (debug_line.call_stack, 83),
                                CHR (10),
                                CHR (9)));
            END LOOP;

            DELETE FROM custom.do_debug
                  WHERE session_id = USERENV ('SESSIONID');
        END IF;

        do_mail_utils.send_mail_close (iretval);
    END;

    PROCEDURE m_end (x_ret_stat VARCHAR2, x_message VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (240) := 'M_END';
    BEGIN
        IF g_mail_debugging
        THEN
            IF x_ret_stat = g_ret_success
            THEN
                m_msg ('--boundarystring');
                m_msg ('Content-Type: text/plain');
                m_msg ('');
            END IF;

            m_msg ('Returning with a status of: ' || x_ret_stat);

            IF NVL (x_ret_stat, g_ret_unexp_error) != g_ret_success
            THEN
                m_msg ('Message: ' || x_message);
            END IF;

            m_end;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    FUNCTION is_edi_customer (p_customer_number   VARCHAR2,
                              p_edi_doctype       VARCHAR2)
        RETURN VARCHAR2
    IS
        x_edi_lookup_cnt   NUMBER;
        x_edi_cust_flag    VARCHAR2 (1);
    BEGIN
        x_edi_lookup_cnt   := 0;
        x_edi_cust_flag    := 'N';

        SELECT COUNT (*)
          INTO x_edi_lookup_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
               AND flv.lookup_code = p_customer_number;

        IF x_edi_lookup_cnt > 0
        THEN
            x_edi_cust_flag   := 'Y';
        END IF;

        RETURN x_edi_cust_flag;
    END;

    FUNCTION isa_id_to_org_id (p_isa_id VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'ISA_ID_TO_ORG_ID';
        x_org_id      NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT SUBSTR (meaning, INSTR (meaning, ';', -1) + 1) org_id
          INTO x_org_id
          FROM fnd_lookup_values flv
         WHERE     lookup_type = 'XXDO_SOA_EDI_ISA_XREF'
               AND language = 'US'
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND lookup_code = p_isa_id;

        msg ('Function ' || l_proc_name || ' returning (' || x_org_id || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION isa_id_to_organization_code (p_isa_id VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proc_name           VARCHAR2 (240) := 'ISA_ID_TO_ORGANIZATION_ID';
        x_organization_code   VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT SUBSTR (SUBSTR (flv.meaning, INSTR (flv.meaning, ';') + 1), 1, INSTR (SUBSTR (flv.meaning, INSTR (flv.meaning, ';') + 1), ';') - 1) organization_code
          INTO x_organization_code
          FROM fnd_lookup_values flv, mtl_parameters mp
         WHERE     flv.lookup_type = 'XXDO_SOA_EDI_ISA_XREF'
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND mp.organization_code =
                   SUBSTR (
                       SUBSTR (flv.meaning, INSTR (flv.meaning, ';') + 1),
                       1,
                         INSTR (
                             SUBSTR (flv.meaning,
                                     INSTR (flv.meaning, ';') + 1),
                             ';')
                       - 1)
               AND lookup_code = p_isa_id;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_organization_code
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_organization_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION organization_code_to_id (p_organization_code VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name         VARCHAR2 (240)
                                := 'ORGANIZATION_CODE_TO_ORGANIZATION_ID';
        x_organization_id   NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT organization_id
          INTO x_organization_id
          FROM mtl_parameters mp
         WHERE mp.organization_code = p_organization_code;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_organization_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_organization_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION isa_id_to_brand (p_isa_id VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proc_name   VARCHAR2 (240) := 'ISA_ID_TO_BRAND';
        x_brand       VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT SUBSTR (meaning, 1, INSTR (meaning, ';') - 1) brand
          INTO x_brand
          FROM fnd_lookup_values flv
         WHERE     lookup_type = 'XXDO_SOA_EDI_ISA_XREF'
               AND language = 'US'
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND lookup_code = p_isa_id;

        msg ('Function ' || l_proc_name || ' returning (' || x_brand || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION customer_number_to_customer_id (p_customer_number VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name         VARCHAR2 (240) := 'CUSTOMER_NUMBER_TO_CUSTOMER_ID';
        x_customer_id       NUMBER;
        -- Start changes by Prasad on 10/1/2014 to overcome issues from standard objects overloaded with custom objects
        x_customer_number   apps.ra_hcustomers.customer_number%TYPE
                                := TO_CHAR (p_customer_number);
    -- End changes by Prasad on 10/1/2014 to overcome issues from standard objects overloaded with custom objects
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT customer_id
          INTO x_customer_id
          FROM                         /* ra_customers -- Changed by Prasad */
               apps.ra_hcustomers
         WHERE customer_number = /* p_customer_number; -- Changed by Prasad */
                                 x_customer_number;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_customer_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_customer_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION order_type_name_to_id (p_order_type VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'ORDER_TYPE_NAME_TO_ID';
        x_order_type_id   NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT transaction_type_id
          INTO x_order_type_id
          FROM oe_transaction_types_tl
         WHERE language = 'US' AND name = p_order_type;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_order_type_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_order_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION order_type_name_to_org_id (p_order_type VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'ORDER_TYPE_NAME_TO_ID';
        x_org_id      NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT otta.org_id
          INTO x_org_id
          FROM oe_transaction_types_tl ottt, oe_transaction_types_all otta
         WHERE     ottt.language = 'US'
               AND ottt.name = p_order_type
               AND otta.transaction_type_id = ottt.transaction_type_id;

        msg ('Function ' || l_proc_name || ' returning (' || x_org_id || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_ship_to_org_id (p_isa_id            VARCHAR2,
                                 p_customer_number   VARCHAR2,
                                 p_store             VARCHAR2:= NULL,
                                 p_dc                VARCHAR2:= NULL,
                                 p_location          VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_proc_name     VARCHAR2 (240) := 'GET_SHIP_TO_ORG_ID';
        l_org_id        NUMBER;
        l_customer_id   NUMBER;
        x_site_use_id   NUMBER;
        l_counter       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        l_org_id   := isa_id_to_org_id (p_isa_id);

        SELECT customer_id
          INTO l_customer_id
          FROM                         /* ra_customers -- Changed by Prasad */
               apps.ra_hcustomers rac
         WHERE rac.customer_number = p_customer_number;

        IF (p_store IS NULL AND p_dc IS NULL AND p_location IS NULL)
        THEN                                           -- find primary ship-to
            BEGIN
                SELECT rsua.site_use_id
                  INTO x_site_use_id
                  FROM             /* ra_addresses_all -- Changed by Prasad */
                       apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                   apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = l_org_id
                       AND raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND rsua.primary_flag = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN       -- can't find a primary, find single active address
                    BEGIN
                        SELECT COUNT (*), MAX (rsua.site_use_id)
                          INTO l_counter, x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.customer_id = l_customer_id
                               AND raa.status = 'A'
                               AND raa.org_id = l_org_id
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A';

                        -- Start for an Issue
                        IF l_counter = 1
                        THEN
                            RETURN x_site_use_id;
                        END IF;

                        SELECT rsua.site_use_id
                          INTO x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.org_id = l_org_id
                               AND raa.customer_id IN --(select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Commented 3.0
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                         WHERE     hcr.cust_account_id =
                                                   l_customer_id
                                               AND hca_parent.cust_account_id =
                                                   hcr.related_cust_account_id
                                               AND hca_parent.attribute1 =
                                                   'ALL BRAND'
                                               AND hcr.cust_account_id =
                                                   hca_child.cust_account_id
                                               AND hca_parent.party_id =
                                                   hca_child.party_id)
                               -- Modified 3.0
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A'
                               AND rsua.primary_flag = 'Y';

                        IF x_site_use_id IS NOT NULL      --l_counter = 1 then
                        THEN
                            RETURN x_site_use_id;
                        END IF;
                    -- End
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            /*select count (*), max (rsua.site_use_id)
                              into l_counter, x_site_use_id
                              from apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                             where raa.customer_id = l_customer_id
                               and raa.status = 'A'
                               and raa.org_id = l_org_id
                               and rsua.address_id = raa.address_id
                               and rsua.site_use_code = 'SHIP_TO'
                               and rsua.status = 'A';

                            if l_counter = 1 then
                              return x_site_use_id;
                            end if;

                            select rsua.site_use_id
                              into x_site_use_id
                              from apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                              where raa.org_id = l_org_id
                                and raa.customer_id in (select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id)
                                and raa.status = 'A'
                                and rsua.address_id = raa.address_id
                                and rsua.site_use_code = 'SHIP_TO'
                                and rsua.status = 'A'
                                and rsua.primary_flag = 'Y';

                            if x_site_use_id IS NOT NULL --l_counter = 1 then
                            then
                              return x_site_use_id;
                            end if;*/
                            x_site_use_id   := NULL;
                    END;
            END;
        ELSIF (p_store IS NOT NULL AND p_dc IS NOT NULL AND p_location IS NULL)
        THEN                                      -- find exact store/DC match
            BEGIN
                SELECT rsua.site_use_id
                  INTO x_site_use_id
                  FROM             /* ra_addresses_all -- Changed by Prasad */
                       apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                   apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = l_org_id
                       AND raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                           LPAD (p_store, 20, '0')
                       AND LPAD (NVL (raa.attribute5, '-NONE-'), 20, '0') =
                           LPAD (p_dc, 20, '0');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT rsua.site_use_id
                          INTO x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.org_id = l_org_id
                               AND raa.customer_id IN --(select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Commented 3.0
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                         WHERE     hcr.cust_account_id =
                                                   l_customer_id
                                               AND hca_parent.cust_account_id =
                                                   hcr.related_cust_account_id
                                               AND hca_parent.attribute1 =
                                                   'ALL BRAND'
                                               AND hcr.cust_account_id =
                                                   hca_child.cust_account_id
                                               AND hca_parent.party_id =
                                                   hca_child.party_id)
                               -- Modified 3.0
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A'
                               AND LPAD (NVL (raa.attribute2, '-NONE-'),
                                         20,
                                         '0') =
                                   LPAD (p_store, 20, '0')
                               AND LPAD (NVL (raa.attribute5, '-NONE-'),
                                         20,
                                         '0') =
                                   LPAD (p_dc, 20, '0');
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_site_use_id   := NULL;
                        WHEN TOO_MANY_ROWS
                        THEN
                            x_site_use_id   := NULL;
                    END;
            END;
        ELSIF (p_store IS NOT NULL AND p_dc IS NULL AND p_location IS NULL)
        THEN                                -- look for inexact store/DC match
            SELECT COUNT (*), MAX (rsua.site_use_id) -- one site for a given store
              INTO l_counter, x_site_use_id
              FROM                 /* ra_addresses_all -- Changed by Prasad */
                   apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                               apps.ra_site_uses_morg rsua
             WHERE     raa.org_id = l_org_id
                   AND raa.customer_id = l_customer_id
                   AND raa.status = 'A'
                   AND rsua.address_id = raa.address_id
                   AND rsua.site_use_code = 'SHIP_TO'
                   AND rsua.status = 'A'
                   AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                       LPAD (p_store, 20, '0');

            --        and raa.attribute5 is not null;
            IF l_counter = 0
            THEN
                SELECT COUNT (*), MAX (rsua.site_use_id) -- one site for a given store
                  INTO l_counter, x_site_use_id
                  FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = l_org_id
                       AND raa.customer_id IN --(select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Commented 3.0
                               (SELECT related_cust_account_id
                                  FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                 WHERE     hcr.cust_account_id =
                                           l_customer_id
                                       AND hca_parent.cust_account_id =
                                           hcr.related_cust_account_id
                                       AND hca_parent.attribute1 =
                                           'ALL BRAND'
                                       AND hcr.cust_account_id =
                                           hca_child.cust_account_id
                                       AND hca_parent.party_id =
                                           hca_child.party_id)
                       -- Modified 3.0
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                           LPAD (p_store, 20, '0');
            END IF;

            IF l_counter != 1
            THEN
                SELECT COUNT (*), MAX (rsua.site_use_id)
                  -- site for a given store marked as edi-enabled
                  INTO l_counter, x_site_use_id
                  FROM             /* ra_addresses_all -- Changed by Prasad */
                       apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                   apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = l_org_id
                       AND raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                           LPAD (p_store, 20, '0')
                       --          and raa.attribute5 is not null
                       AND NVL (raa.attribute7, 'N') = 'Y';

                IF l_counter = 0
                THEN
                    SELECT COUNT (*), MAX (rsua.site_use_id)
                      -- site for a given store marked as edi-enabled
                      INTO l_counter, x_site_use_id
                      FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                     WHERE     raa.org_id = l_org_id
                           AND raa.customer_id IN --(select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Commented 3.0
                                   (SELECT related_cust_account_id
                                      FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                     WHERE     hcr.cust_account_id =
                                               l_customer_id
                                           AND hca_parent.cust_account_id =
                                               hcr.related_cust_account_id
                                           AND hca_parent.attribute1 =
                                               'ALL BRAND'
                                           AND hcr.cust_account_id =
                                               hca_child.cust_account_id
                                           AND hca_parent.party_id =
                                               hca_child.party_id)
                           -- Modified 3.0
                           AND raa.status = 'A'
                           AND rsua.address_id = raa.address_id
                           AND rsua.site_use_code = 'SHIP_TO'
                           AND rsua.status = 'A'
                           AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                               LPAD (p_store, 20, '0')
                           AND NVL (raa.attribute7, 'N') = 'Y';
                END IF;

                IF l_counter != 1
                THEN
                    SELECT COUNT (*), MAX (rsua.site_use_id)
                      -- site for a given store marked as primary
                      INTO l_counter, x_site_use_id
                      FROM         /* ra_addresses_all -- Changed by Prasad */
                           apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                       apps.ra_site_uses_morg rsua
                     WHERE     raa.org_id = l_org_id
                           AND raa.customer_id = l_customer_id
                           AND raa.status = 'A'
                           AND rsua.address_id = raa.address_id
                           AND rsua.site_use_code = 'SHIP_TO'
                           AND rsua.status = 'A'
                           AND LPAD (NVL (raa.attribute2, '-NONE-'), 20, '0') =
                               LPAD (p_store, 20, '0')
                           --          and raa.attribute5 is not null
                           AND NVL (raa.ship_to_flag, 'N') = 'P';

                    IF l_counter = 0
                    THEN
                        SELECT COUNT (*), MAX (rsua.site_use_id)
                          -- site for a given store marked as primary
                          INTO l_counter, x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.org_id = l_org_id
                               AND raa.customer_id IN --(select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Commented 3.0
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                         WHERE     hcr.cust_account_id =
                                                   l_customer_id
                                               AND hca_parent.cust_account_id =
                                                   hcr.related_cust_account_id
                                               AND hca_parent.attribute1 =
                                                   'ALL BRAND'
                                               AND hcr.cust_account_id =
                                                   hca_child.cust_account_id
                                               AND hca_parent.party_id =
                                                   hca_child.party_id)
                               -- Modified 3.0
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A'
                               AND LPAD (NVL (raa.attribute2, '-NONE-'),
                                         20,
                                         '0') =
                                   LPAD (p_store, 20, '0')
                               AND NVL (raa.ship_to_flag, 'N') = 'P';
                    END IF;

                    IF l_counter != 1
                    THEN
                        x_site_use_id   := NULL;
                    END IF;
                END IF;
            END IF;
        ELSIF (p_store IS NULL AND p_dc IS NULL AND p_location IS NOT NULL)
        THEN                                      -- find exact location match
            BEGIN
                SELECT rsua.site_use_id
                  INTO x_site_use_id
                  FROM             /* ra_addresses_all -- Changed by Prasad */
                       apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                   apps.ra_site_uses_morg rsua
                 WHERE     raa.org_id = l_org_id
                       AND raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'SHIP_TO'
                       AND rsua.status = 'A'
                       AND rsua.primary_flag = 'Y'
                       AND raa.attribute2 IS NULL
                       AND raa.attribute5 IS NULL
                       AND rsua.location = p_location;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT rsua.site_use_id
                          INTO x_site_use_id
                          FROM apps.ra_addresses_morg raa, apps.ra_site_uses_morg rsua
                         WHERE     raa.org_id = l_org_id
                               AND raa.customer_id IN -- (select related_cust_account_id from hz_cust_acct_relate_all where cust_account_id = l_customer_id) -- Modified 3.0
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                         WHERE     hcr.cust_account_id =
                                                   l_customer_id
                                               AND hca_parent.cust_account_id =
                                                   hcr.related_cust_account_id
                                               AND hca_parent.attribute1 =
                                                   'ALL BRAND'
                                               AND hcr.cust_account_id =
                                                   hca_child.cust_account_id
                                               AND hca_parent.party_id =
                                                   hca_child.party_id)
                               -- Modified 3.0
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.site_use_code = 'SHIP_TO'
                               AND rsua.status = 'A'
                               AND rsua.primary_flag = 'Y'
                               AND raa.attribute2 IS NULL
                               AND raa.attribute5 IS NULL
                               AND rsua.location = p_location;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_site_use_id   := NULL;
                        WHEN TOO_MANY_ROWS
                        THEN
                            x_site_use_id   := NULL;
                    END;
            END;
        END IF;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_site_use_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_site_use_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_ship_to_location (p_isa_id            VARCHAR2,
                                   p_customer_number   VARCHAR2,
                                   p_store             VARCHAR2:= NULL,
                                   p_dc                VARCHAR2:= NULL,
                                   p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name          VARCHAR2 (240) := 'GET_SHIP_TO_LOCATION';
        x_ship_to_location   VARCHAR2 (240);
    BEGIN
        msg ('-' || lg_package_name || '.' || l_proc_name);

        SELECT location
          INTO x_ship_to_location
          FROM                     /* ra_site_uses_all -- Changed by Prasad */
               apps.ra_site_uses_morg
         WHERE site_use_id = get_ship_to_org_id (p_isa_id, p_customer_number, p_store
                                                 , p_dc, p_location);

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_ship_to_location
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_ship_to_location;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_bill_to_org_id (p_isa_id            VARCHAR2,
                                 p_customer_number   VARCHAR2,
                                 p_store             VARCHAR2:= NULL,
                                 p_dc                VARCHAR2:= NULL,
                                 p_location          VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'GET_BILL_TO_ORG_ID';
        l_org_id          NUMBER;
        l_customer_id     NUMBER;
        x_site_use_id     NUMBER;
        l_counter         NUMBER;
        l_ship_to_site    NUMBER;
        l_primary_site    NUMBER;
        l_brand           VARCHAR2 (240);
        l_override_site   NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        l_org_id   := isa_id_to_org_id (p_isa_id);
        l_brand    := isa_id_to_brand (p_isa_id);

        -- To allow Sanuk to maintain seperate bill-tos
        SELECT customer_id
          INTO l_customer_id
          FROM                         /* ra_customers -- Changed by Prasad */
               apps.ra_hcustomers rac
         WHERE rac.customer_number = p_customer_number;

        SELECT MAX (rsua.site_use_id), COUNT (*)
          INTO l_override_site, l_counter
          FROM                     /* ra_addresses_all -- Changed by Prasad */
               apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                           apps.ra_site_uses_morg rsua
         WHERE     raa.org_id = l_org_id
               AND raa.customer_id = l_customer_id
               AND raa.status = 'A'
               AND rsua.address_id = raa.address_id
               AND rsua.site_use_code = 'BILL_TO'
               AND rsua.status = 'A'
               AND SUBSTR (UPPER (rsua.location), 0, LENGTH (l_brand)) =
                   UPPER (l_brand);

        IF l_counter != 1
        THEN
            l_override_site   := NULL;
        END IF;

        -- End Sanuk band-aid
        BEGIN
            SELECT rsua.site_use_id
              INTO l_primary_site
              FROM                 /* ra_addresses_all -- Changed by Prasad */
                   apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                               apps.ra_site_uses_morg rsua
             WHERE     raa.org_id = l_org_id
                   AND raa.customer_id = l_customer_id
                   AND raa.status = 'A'
                   AND rsua.address_id = raa.address_id
                   AND rsua.site_use_code = 'BILL_TO'
                   AND rsua.status = 'A'
                   AND rsua.primary_flag = 'Y'
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM do_custom.do_brands
                             WHERE UPPER (brand_name) =
                                   SUBSTR (UPPER (rsua.location),
                                           0,
                                           LENGTH (brand_name)));
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                l_primary_site   := NULL;
            WHEN NO_DATA_FOUND
            THEN
                SELECT COUNT (*), MAX (rsua.site_use_id)
                  INTO l_counter, l_primary_site
                  FROM             /* ra_addresses_all -- Changed by Prasad */
                       apps.ra_addresses_morg raa, /* ra_site_uses_all -- Changed by Prasad */
                                                   apps.ra_site_uses_morg rsua
                 WHERE     raa.customer_id = l_customer_id
                       AND raa.status = 'A'
                       AND raa.org_id = l_org_id
                       AND rsua.address_id = raa.address_id
                       AND rsua.site_use_code = 'BILL_TO'
                       AND rsua.status = 'A'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM do_custom.do_brands
                                 WHERE UPPER (brand_name) =
                                       SUBSTR (UPPER (rsua.location),
                                               0,
                                               LENGTH (brand_name)));

                IF l_counter != 1
                THEN
                    l_primary_site   := NULL;
                END IF;
        END;

        BEGIN
            SELECT bill_to_site_use_id
              INTO x_site_use_id
              FROM                 /* ra_site_uses_all -- Changed by Prasad */
                   apps.ra_site_uses_morg
             WHERE site_use_id = get_ship_to_org_id (p_isa_id, p_customer_number, p_store
                                                     , p_dc, p_location);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_site_use_id   := NULL;
        END;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || NVL (l_override_site, NVL (x_site_use_id, l_primary_site))
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        --RETURN NVL (l_override_site, NVL (x_site_use_id, l_primary_site));
        RETURN NVL (l_primary_site, NVL (x_site_use_id, l_override_site)); --W.r.t Version 8.0
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_bill_to_location (p_isa_id            VARCHAR2,
                                   p_customer_number   VARCHAR2,
                                   p_store             VARCHAR2:= NULL,
                                   p_dc                VARCHAR2:= NULL,
                                   p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name          VARCHAR2 (240) := 'GET_BILL_TO_LOCATION';
        x_bill_to_location   VARCHAR2 (240);
    BEGIN
        msg ('-' || lg_package_name || '.' || l_proc_name);

        SELECT location
          INTO x_bill_to_location
          FROM                     /* ra_site_uses_all -- Changed by Prasad */
               apps.ra_site_uses_morg
         WHERE site_use_id = get_bill_to_org_id (p_isa_id, p_customer_number, p_store
                                                 , p_dc, p_location);

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_bill_to_location
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_bill_to_location;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION location_to_site_use_id (p_brand VARCHAR2, p_customer_number VARCHAR2, p_location VARCHAR2
                                      , p_location_type VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name     VARCHAR2 (240) := 'LOCATION_TO_SITE_USE_ID';
        x_location_id   NUMBER;
        l_customer_id   NUMBER;
    BEGIN
        msg ('-' || lg_package_name || '.' || l_proc_name);

        BEGIN
            SELECT customer_id
              INTO l_customer_id
              FROM apps.ra_hcustomers rac
             WHERE rac.customer_number = p_customer_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_customer_id   := NULL;
                msg (
                       'Unable to derive customer id for : '
                    || p_customer_number);
        END;

        SELECT site_use_id
          INTO x_location_id
          FROM                     /* ra_site_uses_all -- Changed by Prasad */
               apps.ra_site_uses_morg rsua, /* ra_addresses_all -- Changed by Prasad */
                                            apps.ra_addresses_morg raa, /* ra_customers -- Changed by Prasad */
                                                                        apps.ra_hcustomers rac
         WHERE --rac.customer_number = p_customer_number-- Comment for CCR0010148
                   raa.customer_id = l_customer_id     -- Added for CCR0010148
               AND raa.customer_id = rac.customer_id
               AND raa.status = 'A'
               AND rsua.address_id = raa.address_id
               AND rsua.status = 'A'
               AND TRIM (rsua.location) = TRIM (p_location)
               AND rsua.site_use_code = p_location_type;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_location_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_location_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT site_use_id
                  INTO x_location_id
                  FROM apps.ra_site_uses_morg rsua, apps.ra_addresses_morg raa, apps.ra_hcustomers rac
                 WHERE     rac.customer_id IN
                               (SELECT related_cust_account_id
                                  FROM hz_cust_acct_relate_all
                                 WHERE cust_account_id = l_customer_id)
                       AND raa.customer_id = rac.customer_id
                       AND raa.status = 'A'
                       AND rsua.address_id = raa.address_id
                       AND rsua.status = 'A'
                       -- AND TRIM (rsua.location) = TRIM (p_location)  --Commented W.r.t Version 15.0
                       AND rsua.location = TRIM (p_location) --W.r.t Version 15.0
                       AND rsua.site_use_code = p_location_type;

                RETURN x_location_id;
            EXCEPTION
                WHEN NO_DATA_FOUND                  --Start W.r.t Version 15.0
                THEN
                    BEGIN
                        SELECT site_use_id
                          INTO x_location_id
                          FROM apps.ra_site_uses_morg rsua, apps.ra_addresses_morg raa, apps.ra_hcustomers rac
                         WHERE     rac.customer_id IN
                                       (SELECT related_cust_account_id
                                          FROM hz_cust_acct_relate_all
                                         WHERE cust_account_id =
                                               l_customer_id)
                               AND raa.customer_id = rac.customer_id
                               AND raa.status = 'A'
                               AND rsua.address_id = raa.address_id
                               AND rsua.status = 'A'
                               AND TRIM (rsua.location) = TRIM (p_location)
                               AND rsua.site_use_code = p_location_type;

                        RETURN x_location_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   'Unhandled exception in function '
                                || lg_package_name
                                || '.'
                                || l_proc_name);
                            msg (
                                '-' || lg_package_name || '.' || l_proc_name);
                            RETURN NULL;
                    END;                              --END W.r.t Version 15.0
            END;
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_order_type_name (p_isa_id            VARCHAR2,
                                  p_customer_number   VARCHAR2,
                                  p_store             VARCHAR2:= NULL,
                                  p_dc                VARCHAR2:= NULL,
                                  p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name         VARCHAR2 (240) := 'GET_ORDER_TYPE_NAME';
        l_bill_to_org_id    NUMBER;
        l_ship_to_org_id    NUMBER;
        l_order_type_id     NUMBER;
        x_order_type_name   VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        l_bill_to_org_id   :=
            get_bill_to_org_id (p_isa_id, p_customer_number, p_store,
                                p_dc, p_location);
        l_ship_to_org_id   :=
            get_ship_to_org_id (p_isa_id, p_customer_number, p_store,
                                p_dc, p_location);

        BEGIN
            SELECT order_type_id
              INTO l_order_type_id
              FROM hz_cust_site_uses_all
             --WHERE site_use_id = l_ship_to_org_id; -- W.r.t Version 8.0
             WHERE site_use_id = l_bill_to_org_id;        -- W.r.t Version 8.0
        EXCEPTION
            WHEN OTHERS
            THEN
                l_order_type_id   := NULL;
        END;

        IF l_order_type_id IS NULL
        THEN
            BEGIN
                SELECT order_type_id
                  INTO l_order_type_id
                  FROM hz_cust_site_uses_all
                 WHERE site_use_id = l_ship_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_order_type_id   := NULL;
            END;
        END IF;

        SELECT name
          INTO x_order_type_name
          FROM oe_transaction_types_tl
         WHERE language = 'US' AND transaction_type_id = l_order_type_id;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_order_type_name
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_order_type_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_price_list_id (p_brand VARCHAR2, p_order_type_name VARCHAR2, p_ordered_date VARCHAR2
                                , p_request_date VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'GET_PRICE_LIST_ID';
        l_order_type_id   NUMBER;
        x_price_list_id   NUMBER;
        l_ordered_date    DATE;
        l_request_date    DATE;
        l_ret_stat        VARCHAR2 (1);
        l_err             VARCHAR2 (2000);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        msg ('Parameters p_brand: [' || p_brand || ']');
        msg ('Parameters p_order_type_name: [' || p_order_type_name || ']');
        msg ('Parameters p_ordered_date: [' || p_ordered_date || ']');
        msg ('Parameters p_request_date: [' || p_request_date || ']');
        l_ordered_date    := TO_DATE (p_ordered_date, 'YYYY-MM-DD');
        l_request_date    := TO_DATE (p_request_date, 'YYYY-MM-DD');
        msg ('Parameters l_ordered_date: [' || l_ordered_date || ']');
        msg ('Parameters l_request_date: [' || l_request_date || ']');
        l_order_type_id   := order_type_name_to_id (p_order_type_name);
        apps.do_oe_utils.get_default_price_list (
            p_brand               => p_brand,
            p_creation_date       => l_ordered_date,
            p_request_date        => l_request_date,
            p_order_type_id       => l_order_type_id,
            p_price_list_id       => NULL,
            x_new_price_list_id   => x_price_list_id,
            x_return_status       => l_ret_stat,
            x_error_text          => l_err);

        IF x_price_list_id IS NULL
        THEN
            apps.do_oe_utils.get_default_price_list (
                p_brand               => p_brand,
                p_creation_date       => l_ordered_date,
                p_request_date        => TRUNC (SYSDATE),
                p_order_type_id       => l_order_type_id,
                p_price_list_id       => NULL,
                x_new_price_list_id   => x_price_list_id,
                x_return_status       => l_ret_stat,
                x_error_text          => l_err);
        END IF;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_price_list_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_price_list_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    PROCEDURE get_adj_details (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2, p_unit_price IN NUMBER, x_list_header_id OUT NUMBER, x_list_line_id OUT NUMBER
                               , x_line_type_code OUT VARCHAR2, x_percentage OUT NUMBER, x_list_price OUT NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_price_list_id   NUMBER;
        l_list_price      NUMBER;
        l_proc_name       VARCHAR2 (240) := 'GET_ADJ_DETAILS';
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        msg ('Brand: ' || p_brand);

        ---------------BT Change: 21-Jan-2015
        SELECT user_id
          INTO gn_user_id
          FROM fnd_user
         WHERE user_name = 'BATCH';

        SELECT user_id
          INTO gn_user_id1
          FROM fnd_user
         --  WHERE user_name = 'BBURNS';
         WHERE user_name = 'BRIANB';                        -- Changed for BT.

        SELECT responsibility_id
          INTO gn_resp_id
          FROM fnd_responsibility_vl
         -- WHERE responsibility_name = 'Order Management Super User - US';
         WHERE responsibility_name = 'Deckers Order Management User - US';

        -- Modified for 12.0 : getting resp from the global variable
        -- CCR0007582 - EBS:O2F: Order Import Defects
        gn_resp_id     := g_resp_id;

        -- Modified for 2.0;
        SELECT application_id
          INTO gn_appln_id
          FROM fnd_application_vl
         WHERE application_name = 'Order Management';

        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        SELECT COUNT (*)
          INTO g_n_temp
          FROM v$database
         WHERE name = 'PROD';

        ---------------BT Change: 21-Jan-2015
        IF NVL (fnd_global.user_id, -1) = -1
        THEN
            IF g_n_temp = 1 AND NVL (fnd_global.user_id, -1) = -1
            THEN                          -- if it's prod then log in as BATCH
                /*fnd_global.apps_initialize (user_id        => 1037,
                                            resp_id        => 50225,
                                            resp_appl_id   => 20003);

                fnd_global.initialize (l_buffer_number,
                                       1037,
                                       50225,
                                       20003,
                                       0,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       666,
                                       -1);*/

                --Start BT Change on 21-Jan-2015
                fnd_global.apps_initialize (user_id        => gn_user_id,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_appln_id);
            --Start BT Change on 21-Jan-2015
            ELSE                                 -- otherwise log in as BBURNS
                /*fnd_global.apps_initialize (user_id        => 1062,
                                            resp_id        => 50225,
                                            resp_appl_id   => 20003);
                fnd_global.initialize (l_buffer_number,
                                       1062,
                                       50225,
                                       20003,
                                       0,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       666,
                                       -1);*/
                --Start BT Change on 21-Jan-2015
                fnd_global.apps_initialize (user_id        => gn_user_id1,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_appln_id);
            --Start BT Change on 21-Jan-2015
            END IF;

            fnd_file.put_names (
                'EDI_UTILS_' || USERENV ('SESSIONID') || '.log',
                'EDI_UTILS_' || USERENV ('SESSIONID') || '.out',
                '/usr/tmp');
        END IF;

        --Added by Sreenath for BT - Start

        /*fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);*/

        /*fnd_global.initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);  */

        --Added by Sreenath for BT - End
        IF fnd_global.user_id = gn_user_id1                             --1062
        THEN                          -- if BBURNS then crank up the debugging
            do_debug_tools.enable_table (10000000);
            fnd_profile.put ('DO_EDI_MAIL_DEBUG', 'Y');
            fnd_profile.put ('DO_EDI_MAIL_DEBUG_DETAIL', 'Y');
        END IF;

        l_price_list_id   :=
            get_price_list_id (p_brand => p_brand, p_order_type_name => p_order_type_name, p_ordered_date => p_ordered_date
                               , p_request_date => p_request_date);
        msg ('Price List ID [' || l_price_list_id || ']');

        BEGIN
            l_list_price   :=
                do_oe_utils.do_get_price_list_value (
                    p_price_list_id            => l_price_list_id,
                    p_inventory_item_id        => sku_to_iid (p_sku),
                    p_use_oracle_pricing_api   => 'Y');

            IF l_list_price IS NULL
            THEN
                msg ('Oracle Standard return <null> trying custom');
                l_list_price   :=
                    do_oe_utils.do_get_price_list_value (
                        p_price_list_id            => l_price_list_id,
                        p_inventory_item_id        => sku_to_iid (p_sku),
                        p_use_oracle_pricing_api   => 'N');
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Exception with oracle API [' || SQLERRM || ']');
                l_list_price   :=
                    do_oe_utils.do_get_price_list_value (
                        p_price_list_id            => l_price_list_id,
                        p_inventory_item_id        => sku_to_iid (p_sku),
                        p_use_oracle_pricing_api   => 'N');
        END;

        x_list_price   := l_list_price;
        msg ('List Price [' || l_list_price || ']');

        IF NVL (l_list_price, 0) = 0
        THEN
            msg ('-' || lg_package_name || '.' || l_proc_name);
            x_line_type_code   := 'ERROR';
            RETURN;
        END IF;

        x_percentage   :=
            ROUND (ABS (p_unit_price / l_list_price - 1) * 100, 2);
        msg ('Percentage [' || x_percentage || ']');

        IF p_unit_price > l_list_price
        THEN
            BEGIN
                SELECT qll.list_header_id, qll.list_line_id, qll.list_line_type_code
                  INTO x_list_header_id, x_list_line_id, x_line_type_code
                  FROM qp_list_headers qlh, qp_list_headers_b qlhb, qp_list_lines qll
                 WHERE     qlh.list_header_id = qlhb.list_header_id
                       AND qll.list_header_id = qlhb.list_header_id
                       AND qlhb.list_type_code = 'SLT'
                       AND qlhb.automatic_flag = 'N'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       qlhb.start_date_active,
                                                       SYSDATE - 1)
                                               AND NVL (qlhb.end_date_active,
                                                        SYSDATE + 1)
                       AND qlhb.active_flag = 'Y'
                       AND qlhb.currency_code = p_currency
                       AND (qlhb.global_flag = 'Y' OR NVL (qlhb.orig_org_id, order_type_name_to_org_id (p_order_type_name)) = order_type_name_to_org_id (p_order_type_name))
                       AND qll.list_line_type_code = 'SUR'
                       AND qll.modifier_level_code = 'LINE'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       qll.start_date_active,
                                                       SYSDATE - 1)
                                               AND NVL (qll.end_date_active,
                                                        SYSDATE + 1)
                       AND qll.automatic_flag = 'N'
                       AND qll.override_flag = 'Y'
                       AND NVL (qll.operand, 0) = 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unhandled exception in function '
                        || lg_package_name
                        || '.'
                        || l_proc_name);
                    msg ('-' || lg_package_name || '.' || l_proc_name);
            END;
        ELSIF p_unit_price < l_list_price
        THEN
            BEGIN
                SELECT qll.list_header_id, qll.list_line_id, qll.list_line_type_code
                  INTO x_list_header_id, x_list_line_id, x_line_type_code
                  FROM qp_list_headers qlh, qp_list_headers_b qlhb, qp_list_lines qll
                 WHERE     qlh.list_header_id = qlhb.list_header_id
                       AND qll.list_header_id = qlhb.list_header_id
                       AND qlhb.list_type_code = 'DLT'
                       AND qlhb.automatic_flag = 'N'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       qlhb.start_date_active,
                                                       SYSDATE - 1)
                                               AND NVL (qlhb.end_date_active,
                                                        SYSDATE + 1)
                       AND qlhb.active_flag = 'Y'
                       AND qlhb.currency_code = p_currency
                       AND (qlhb.global_flag = 'Y' OR NVL (qlhb.orig_org_id, order_type_name_to_org_id (p_order_type_name)) = order_type_name_to_org_id (p_order_type_name))
                       AND qll.list_line_type_code = 'DIS'
                       AND qll.modifier_level_code = 'LINE'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       qll.start_date_active,
                                                       SYSDATE - 1)
                                               AND NVL (qll.end_date_active,
                                                        SYSDATE + 1)
                       AND qll.automatic_flag = 'N'
                       AND qll.override_flag = 'Y'
                       AND NVL (qll.operand, 0) = 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Unhandled exception in function '
                        || lg_package_name
                        || '.'
                        || l_proc_name);
                    msg ('-' || lg_package_name || '.' || l_proc_name);
            END;
        ELSE
            x_list_header_id   := NULL;
            x_list_line_id     := NULL;
            x_line_type_code   := 'NONE';
        END IF;

        msg ('-' || lg_package_name || '.' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
    END;

    FUNCTION adj_required (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                           , p_unit_price IN NUMBER)
        RETURN VARCHAR2
    IS
        l_proc_name        VARCHAR2 (240) := 'ADJ_REQUIRED';
        x_adj              VARCHAR2 (240);
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);

        IF NVL (x_line_type_code, 'NONE') = 'NONE'
        THEN
            x_adj   := 'N';
        ELSIF x_line_type_code = 'ERROR'
        THEN
            x_adj   := 'E';
        ELSE
            x_adj   := 'Y';
        END IF;

        msg ('Function ' || l_proc_name || ' returning (' || x_adj || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_adj;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_list_header_id (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                     , p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LIST_HEADER_ID';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_header_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_list_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_list_line_id (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                   , p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LIST_LINE_ID';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_line_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_list_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_line_type_code (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                     , p_unit_price IN NUMBER)
        RETURN VARCHAR2
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_LINE_TYPE_CODE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_line_type_code
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_line_type_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_adj_percentage (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                 , p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_ADJ_PERCENTAGE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_percentage
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_percentage;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_list_price (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                             , p_unit_price IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name        VARCHAR2 (240) := 'GET_LIST_PRICE';
        x_list_header_id   NUMBER;
        x_list_line_id     NUMBER;
        x_line_type_code   VARCHAR2 (240);
        x_percentage       NUMBER;
        x_list_price       NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        get_adj_details (p_brand             => p_brand,
                         p_order_type_name   => p_order_type_name,
                         p_currency          => p_currency,
                         p_ordered_date      => p_ordered_date,
                         p_request_date      => p_request_date,
                         p_sku               => p_sku,
                         p_unit_price        => p_unit_price,
                         x_list_header_id    => x_list_header_id,
                         x_list_line_id      => x_list_line_id,
                         x_line_type_code    => x_line_type_code,
                         x_percentage        => x_percentage,
                         x_list_price        => x_list_price);
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_list_price
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        --x_list_price := 25; -- added by sreenath for BT. should be removed after testing
        RETURN x_list_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    --x_list_price := 24; -- added by sreenath for BT. should be removed after testing
    END;

    FUNCTION get_booked_flag (p_brand             VARCHAR2,
                              p_customer_number   VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name     VARCHAR2 (240) := 'GET_BOOKED_FLAG';
        x_booked_flag   VARCHAR2 (1);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_booked_flag   := 'Y';
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_booked_flag
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_booked_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_order_class (p_isa_id VARCHAR2, p_customer_number VARCHAR2:= NULL, p_request_date DATE:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name     VARCHAR2 (240) := 'GET_ORDER_CLASS';
        x_order_class   VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_order_class   := 'PRE-SEASON SPRING';
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_order_class
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_order_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_kco_header_id (p_brand VARCHAR2, p_customer_number VARCHAR2, p_department VARCHAR2:= NULL, p_first_item_id NUMBER:= NULL, p_store VARCHAR2:= NULL, p_dc VARCHAR2:= NULL
                                , p_location VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'GET_KCO_HEADER_ID';
        x_kco_header_id   NUMBER;
    BEGIN
        --isa_id_to_brand(p_isa_id varchar2)
        -- Start changes by Prasad on 10/2/2014 for BT CRP2 KCO dependency in the SOA code snippets
        /*         msg ('+' || lg_package_name || '.' || l_proc_name);
                 x_kco_header_id := NULL;

                 SELECT kco_header_id
                   INTO x_kco_header_id
                   FROM (  SELECT TO_NUMBER (meaning) AS kco_header_id
                             FROM custom.do_edi_lookup_values
                            WHERE     lookup_type = '850_DEF_KCO'
                                  AND enabled_flag = 'Y'
                                  AND lookup_code =
                                         customer_number_to_customer_id (
                                            p_customer_number)
                                  AND brand IN ('ALL', p_brand)
                         ORDER BY DECODE (brand, 'ALL', 1, 0))
                  WHERE ROWNUM = 1;

                 msg (
                       'Function '
                    || l_proc_name
                    || ' returning ('
                    || x_kco_header_id
                    || ')');
                 msg ('-' || lg_package_name || '.' || l_proc_name);
                 RETURN x_kco_header_id;*/
        RETURN NULL;
    -- Start changes by Prasad on 10/2/2014 for BT CRP2 KCO dependency in the SOA code snippets
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_created_by (p_brand             VARCHAR2:= NULL,
                             p_customer_number   VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_proc_name    VARCHAR2 (240) := 'GET_CREATED_BY';
        x_created_by   NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_created_by   := 1037;
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_created_by
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_created_by;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_updated_by (p_brand             VARCHAR2:= NULL,
                             p_customer_number   VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_proc_name    VARCHAR2 (240) := 'GET_UPDATED_BY';
        x_updated_by   NUMBER;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_updated_by   := 1037;
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_updated_by
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_updated_by;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    /* Since shipping and packing instruction will be populated based on the setup so commenting this code

       FUNCTION get_shipping_instructions (p_isa_id             VARCHAR2,
                                           p_customer_number    VARCHAR2)
          RETURN VARCHAR2
       IS
          l_proc_name               VARCHAR2 (240) := 'GET_SHIPPING_INSTRUCTIONS';
          x_shipping_instructions   VARCHAR2 (2000);
       BEGIN
          msg ('+' || lg_package_name || '.' || l_proc_name);

          BEGIN
             SELECT attribute_large
               INTO x_shipping_instructions
               FROM (  SELECT attribute_large
                         FROM do_custom.do_customer_lookups
                        WHERE     lookup_type = 'DO_DEF_SHIPPING_INSTRUCTS'
                              AND brand IN ('ALL', isa_id_to_brand (p_isa_id))
                              AND customer_id =
                                     customer_number_to_customer_id (
                                        p_customer_number)
                              AND enabled_flag = 'Y'
                     ORDER BY DECODE (brand, 'ALL', 1, 0))
              WHERE ROWNUM = 1;
          EXCEPTION
             WHEN NO_DATA_FOUND
             THEN
                x_shipping_instructions := NULL;
          END;

          msg (
                'Function '
             || l_proc_name
             || ' returning ('
             || x_shipping_instructions
             || ')');
          msg ('-' || lg_package_name || '.' || l_proc_name);
          RETURN x_shipping_instructions;
       EXCEPTION
          WHEN OTHERS
          THEN
             msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
             msg ('-' || lg_package_name || '.' || l_proc_name);
             RETURN NULL;
       END;

       FUNCTION get_packing_instructions (p_isa_id             VARCHAR2,
                                          p_customer_number    VARCHAR2)
          RETURN VARCHAR2
       IS
          l_proc_name              VARCHAR2 (240) := 'GET_PACKING_INSTRUCTIONS';
          x_packing_instructions   VARCHAR2 (2000);
       BEGIN
          msg ('+' || lg_package_name || '.' || l_proc_name);

          BEGIN
             SELECT attribute_large
               INTO x_packing_instructions
               FROM (  SELECT attribute_large
                         FROM do_custom.do_customer_lookups
                        WHERE     lookup_type = 'DO_DEF_PACKING_INSTRUCTS'
                              AND brand IN ('ALL', isa_id_to_brand (p_isa_id))
                              AND customer_id =
                                     customer_number_to_customer_id (
                                        p_customer_number)
                              AND enabled_flag = 'Y'
                     ORDER BY DECODE (brand, 'ALL', 1, 0))
              WHERE ROWNUM = 1;
          EXCEPTION
             WHEN NO_DATA_FOUND
             THEN
                x_packing_instructions := NULL;
          END;

          msg (
                'Function '
             || l_proc_name
             || ' returning ('
             || x_packing_instructions
             || ')');
          msg ('-' || lg_package_name || '.' || l_proc_name);
          RETURN x_packing_instructions;
       EXCEPTION
          WHEN OTHERS
          THEN
             msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
             msg ('-' || lg_package_name || '.' || l_proc_name);
             RETURN NULL;
       END;
    */

    FUNCTION get_conversion_type_code (p_brand           VARCHAR2,
                                       p_currency_code   VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proc_name              VARCHAR2 (240) := 'GET_CONVERSION_TYPE_CODE';
        x_conversion_type_code   VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_conversion_type_code   := NULL;
        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_conversion_type_code
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_conversion_type_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION upc_to_sku (p_upc_code VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proc_name   VARCHAR2 (240) := 'UPC_TO_SKU';
        x_sku         VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        x_sku   := iid_to_sku (upc_to_iid (p_upc_code));
        msg ('Function ' || l_proc_name || ' returning (' || x_sku || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_sku;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION buyer_item_to_sku (p_customer_number   VARCHAR2,
                                p_buyer_item        VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proc_name   VARCHAR2 (240) := 'BUYER_ITEM_TO_SKU';
        x_sku         VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        SELECT inventory_item_id
          INTO x_sku
          FROM do_edi.do_edi_customer_item_xref
         WHERE     customer_id =
                   customer_number_to_customer_id (p_customer_number)
               AND buyer_item_number = p_buyer_item;

        msg ('Function ' || l_proc_name || ' returning (' || x_sku || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_sku;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_sku_cross_reference (p_customer_number VARCHAR2, p_upc_code VARCHAR2:= NULL, p_buyer_item VARCHAR2:= NULL
                                      , p_brand VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_proc_name   VARCHAR2 (240) := 'GET_SKU_CROSS_REFERENCE';
        x_sku         VARCHAR2 (240);
        l_brand       VARCHAR2 (240);
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);

        IF p_upc_code IS NOT NULL AND p_buyer_item IS NULL
        THEN
            x_sku   := upc_to_sku (p_upc_code);
        ELSIF p_upc_code IS NULL AND p_buyer_item IS NOT NULL
        THEN
            x_sku   := buyer_item_to_sku (p_customer_number, p_buyer_item);
        ELSIF p_upc_code IS NOT NULL AND p_buyer_item IS NOT NULL
        THEN
            IF upc_to_sku (p_upc_code) =
               buyer_item_to_sku (p_customer_number, p_buyer_item)
            THEN
                x_sku   := upc_to_sku (p_upc_code);
            ELSIF     upc_to_sku (p_upc_code) IS NOT NULL
                  AND buyer_item_to_sku (p_customer_number, p_buyer_item)
                          IS NULL
            THEN
                x_sku   := upc_to_sku (p_upc_code);
                msg (
                       'Missing Buyer Item ('
                    || p_buyer_item
                    || ') should equate to UPC ('
                    || upc_to_sku (p_upc_code)
                    || ').');
            ELSE
                msg (
                       'Miss-match in UPC ('
                    || upc_to_sku (p_upc_code)
                    || ') and Buyer Item'
                    || buyer_item_to_sku (p_customer_number, p_buyer_item)
                    || ' SKUs');
                x_sku   := NULL;
            END IF;
        ELSE
            x_sku   := NULL;
        END IF;

        SELECT mcb.segment1
          INTO l_brand
          FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
         WHERE --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
                                                    --msib.organization_id = 7
                   msib.organization_id IN
                       (SELECT organization_id
                          FROM org_organization_definitions
                         WHERE organization_name = 'MST_Deckers_Item_Master')
               --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
               AND msib.inventory_item_id = sku_to_iid (x_sku)
               AND mic.organization_id = msib.organization_id
               AND mic.inventory_item_id = msib.inventory_item_id
               --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
               --AND MIC.CATEGORY_SET_ID = 1
               AND mic.category_set_id IN
                       (SELECT category_set_id
                          FROM mtl_category_sets
                         WHERE category_set_name = 'Inventory')
               --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
               AND mcb.category_id = mic.category_id;

        /* -- W.r.t CCR0010110
            IF p_brand IS NOT NULL
            THEN
              IF NVL (l_brand, 'No Brand') != p_brand
              THEN
                x_sku :=
                  SUBSTR (
                       'ERROR Brand MisMatch for '
                    || x_sku
                    || ' expected ('
                    || l_brand
                    || ') received ('
                    || p_brand
                    || ')',
                    1,
                    240);
              END IF;
            END IF;

         */
        -- W.r.t CCR0010110

        msg ('Function ' || l_proc_name || ' returning (' || x_sku || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        --Added by Prasad CHECK HERE- Removed this from the code on instance to make sure rest if it works
        /*  if (p_upc_code = '737045379821') then
          x_sku:='30084';
          elsif p_upc_code = '737045379852' then
          x_sku:='30097';
          else
          x_sku:='30084';
          end if;        */
        -- End of additions
        RETURN x_sku;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    PROCEDURE edi_invoice_trigger (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
    IS
        l_proc_name              VARCHAR2 (240) := 'EDI_INVOICE_TRIGGER';
        l_invoice                VARCHAR2 (240);
        x_event_parameter_list   wf_parameter_list_t;
        x_param                  wf_parameter_t;
        x_event_name             VARCHAR2 (100)
            := 'xx.oracle.apps.shipment_invoice_complete';
        --xx.oracle.apps.shipment_complete
        x_event_key              VARCHAR2 (100);
        x_parameter_index        NUMBER := 0;
    BEGIN
        msg ('+' || lg_package_name || '.' || l_proc_name);
        l_invoice                                    := p_event.event_key;
        x_event_parameter_list                       := wf_parameter_list_t ();
        x_param                                      := wf_parameter_t (NULL, NULL);
        x_event_parameter_list.EXTEND;
        x_param.setname ('INVOICE_ID');
        x_param.setvalue (l_invoice);
        x_parameter_index                            := x_parameter_index + 1;
        x_event_parameter_list (x_parameter_index)   := x_param;
        x_event_key                                  := l_invoice;
        wf_event.raise (p_event_name   => x_event_name,
                        p_event_key    => x_event_key,
                        p_parameters   => x_event_parameter_list);
        msg ('Procedure ' || l_proc_name || ' returning');
        msg ('-' || lg_package_name || '.' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in procedure '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
    END;

    -- Start of Amazon Split Line

    PROCEDURE xxdo_edi_amzn_split_line (
        p_order_number IN oe_order_headers_all.order_number%TYPE)
    IS
        l_proc_name             VARCHAR2 (2000);
        l_split_line_id         NUMBER;
        l_org_line_quantity     NUMBER;
        l_split_line_quantity   NUMBER;
        l_error_text            VARCHAR2 (2000);
        l_split_line_cnt        NUMBER;
        l_split_line_total      NUMBER;
        l_split_cust            VARCHAR (1);
        l_cust_id               NUMBER;
        l_ssd                   DATE;
        l_hold_id               oe_hold_definitions.hold_id%TYPE;
        l_user_id               fnd_user.user_id%TYPE;
        l_resp_id               fnd_responsibility_tl.responsibility_id%TYPE;
        l_app_id                fnd_responsibility_tl.application_id%TYPE;
        l_order_number          NUMBER;
        l_header_id             NUMBER;
        x_atp_qty               NUMBER;
        v_msg_data              VARCHAR2 (2000);
        v_err_code              VARCHAR2 (2000);
        x_req_date_qty          NUMBER;
        x_available_date        DATE;
        ln_line_qnty            NUMBER;
        lv_customer_number      VARCHAR2 (2000);                 --Version 5.0
        lv_customer_name        VARCHAR2 (2000);                 --Version 5.0
        lv_brand                VARCHAR2 (2000);                 --Version 5.0
        lv_op_name              VARCHAR2 (2000);                 --Version 5.0
        lv_demand_class         VARCHAR2 (2000);                 --Version 5.0
        lv_cust_po_number       VARCHAR2 (2000);                 --Version 5.0
        ln_match_found          NUMBER := 0;                     --Version 5.0
        ln_order_source_id      NUMBER;                          --Version 5.0
        ln_order_type_id        NUMBER;                          --Version 5.0
        ln_org_id               NUMBER;                          --Version 5.0
        ln_atp_qty              NUMBER;                          --Version 5.0

        ln_blk_cnt              NUMBER := 0;                           --v16.1
        ld_req_ship_date        DATE;                                  --v16.1

        CURSOR c_lines (p_order_number NUMBER)
        IS
              SELECT line_id, line_number, ordered_quantity,
                     inventory_item_id, oola.order_quantity_uom, oola.ship_from_org_id,
                     oola.request_date, oola.latest_acceptable_date,   --v16.1
                                                                     oola.demand_class_code,
                     oola.flow_status_code
                FROM oe_order_headers_all ooha, oe_order_lines_all oola
               WHERE     ooha.order_number = p_order_number
                     AND oola.header_id = ooha.header_id
            ORDER BY line_id;
    BEGIN
        l_proc_name          := 'xxdo_edi_amzn_split_line';
        l_order_number       := p_order_number;
        l_split_line_total   := 0;
        l_split_line_cnt     := 0;
        write_to_table ('PO Split Order Number', l_order_number);

        BEGIN
            SELECT header_id, sold_to_org_id, org_id,
                   order_source_id,                        --W.r.t Version 5.0
                                    order_type_id, demand_class_code, --W.r.t Version 5.0
                   cust_po_number                          --W.r.t Version 5.0
              INTO l_header_id, l_cust_id, ln_org_id, ln_order_source_id, --W.r.t Version 5.0
                              ln_order_type_id, lv_demand_class, --W.r.t Version 5.0
                                                                 lv_cust_po_number --W.r.t Version 5.0
              FROM oe_order_headers_all
             WHERE order_number = l_order_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (
                    'Cust po number/order source /order type not fetched');
                write_to_table (
                    'In function  :: xxdo_edi_amzn_split_line ',
                       'Cust po number/order source /order type not fetched '
                    || SQLERRM);
        END;

        --Start W.r.t Version 5.0
        BEGIN
            SELECT hca.account_number, hca.account_name
              INTO lv_customer_number, lv_customer_name
              FROM oe_order_headers_all ooh, hz_cust_accounts hca
             WHERE     ooh.sold_to_org_id = hca.cust_account_id -- or a.invoice_to_org_id
                   AND order_number = l_order_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_customer_number   := 'ALL';
                do_debug_tools.msg ('Customer name and number not fetched');
                write_to_table (
                    'In function  :: xxdo_edi_amzn_split_line ',
                    'Customer name and number not fetched ' || SQLERRM);
        END;

        BEGIN
            --Start changes v16.1
            SELECT COUNT (*)
              INTO ln_blk_cnt
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_ONT_SPLIT_SCHEDULE_BOOKING'
                   AND language = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND lookup_code = ln_order_type_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));

            IF ln_blk_cnt > 0
            THEN
                ln_match_found   := 0;
            ELSE
                --End changes v16.1

                SELECT COUNT (1)
                  INTO ln_match_found
                  FROM xxdo_orders_split
                 WHERE     NVL (org_id, ln_org_id) = ln_org_id
                       AND NVL (order_source_id, ln_order_source_id) =
                           ln_order_source_id
                       AND NVL (order_type_id, ln_order_type_id) =
                           ln_order_type_id
                       --AND NVL (customer_number, lv_customer_number) = lv_customer_number
                       AND NVL (demand_class, NVL (lv_demand_class, 'ALL')) =
                           NVL (lv_demand_class, 'ALL')
                       AND NVL (customer_po_number,
                                NVL (lv_cust_po_number, 'ALL')) =
                           NVL (lv_cust_po_number, 'ALL')
                       AND NVL (customer_number, lv_customer_number) IN
                               (SELECT DISTINCT lv_customer_number
                                  FROM DUAL
                                UNION
                                SELECT DISTINCT hca_parent.account_number
                                  FROM hz_cust_acct_relate_all hcr, hz_cust_accounts hca_child, hz_cust_accounts hca_parent
                                 WHERE     hca_parent.cust_account_id =
                                           hcr.related_cust_account_id
                                       AND hca_parent.attribute1 =
                                           'ALL BRAND'
                                       AND hca_child.account_number =
                                           lv_customer_number
                                       AND hcr.cust_account_id =
                                           hca_child.cust_account_id
                                       AND hca_parent.party_id =
                                           hca_child.party_id)
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (begin_date)
                                               AND TRUNC (
                                                       NVL (end_date,
                                                            '31-DEC-9999'));
            END IF;                                                    --v16.1
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_match_found   := 0;
                ln_blk_cnt       := 0;                                 --v16.1
                do_debug_tools.msg ('Unexpected error occured');
                write_to_table ('In function  :: xxdo_edi_amzn_split_line ',
                                ' Unexpected error occured ');
        END;

        /*
        BEGIN
        SELECT NVL (meaning, 'N')
          INTO l_split_cust
          FROM custom.do_edi_lookup_values
         WHERE lookup_type = '850_SPL_AND_SCH_APPLY_CS_HOLD'
           AND lookup_code = l_cust_id
           AND NVL(enabled_flag,'N') = 'Y';
        EXCEPTION
           WHEN OTHERS
           THEN
           l_split_cust :=  'N';
            do_debug_tools.msg ( 'Lookup 850_SPL_AND_SCH_APPLY_CS_HOLD is not defined');
          write_to_table('In function  :: xxdo_edi_amzn_split_line', 'Lookup 850_SPL_AND_SCH_APPLY_CS_HOLD is not defined');
        END;
        */
        --End W.r.t Version 5.0
        BEGIN
            SELECT DISTINCT hold_id
              INTO l_hold_id
              FROM oe_hold_definitions
             WHERE UPPER (name) = 'CR - ACCOUNT PAST DUE';
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (
                    'Cannot found the HOLD ' || l_proc_name || '-' || SQLERRM);
        END;

        --Start changes 17.2
        -- if the user id -1 then only consider user as batch
        l_user_id            := fnd_global.user_id;

        IF NVL (l_user_id, -1) = -1
        THEN
            --End changes 17.2

            BEGIN
                SELECT user_id
                  INTO l_user_id
                  FROM fnd_user
                 WHERE user_name = fnd_profile.VALUE ('XXDO_ADMIN_USER');
            --Profile option created for the Username 'BATCH' --1157
            EXCEPTION
                WHEN OTHERS
                THEN
                    do_debug_tools.msg (
                           'User does not exists'
                        || l_proc_name
                        || '-'
                        || SQLERRM);
            END;
        END IF;                                                    -- end 17.2

        BEGIN
            SELECT application_id, responsibility_id
              INTO l_app_id, l_resp_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       fnd_profile.VALUE ('XXDO_EDI_HOLD_RESPONSIBILITY')
                   --'Deckers Order Management User - US' Modified Mar 23rd for SIT Issue
                   AND language = 'US';

            -- Modified for 12.0 : getting resp from the global variable initialize with resp id from session
            -- CCR0007582 - EBS:O2F: Order Import Defects
            l_resp_id   := g_resp_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (
                       'Responsibility or Application does not exists'
                    || l_proc_name
                    || '-'
                    || SQLERRM);
        END;

        --W.r.t  Version 7.0
        /*
           fnd_global.apps_initialize (user_id           => l_user_id,
                                      resp_id           => l_resp_id,
                                      resp_appl_id      => l_app_id
                                     );
                                     */
        write_to_table ('Split Customer', l_split_cust);
        write_to_table ('Split match ', ln_match_found);

        --  IF l_split_cust = 'Y'  --W.r.t Version 5.0
        IF ln_match_found = 0
        THEN
            --W.r.t  Version 7.0
            fnd_global.apps_initialize (user_id        => l_user_id,
                                        resp_id        => l_resp_id,
                                        resp_appl_id   => l_app_id); --W.r.t  Version 7.0

            do_debug_tools.msg (
                'Checking lines for customer id : ' || l_cust_id);

            FOR c_line IN c_lines (l_order_number)
            LOOP
                IF c_line.flow_status_code = 'BOOKED'      --W.r.t Version 5.0
                THEN
                    BEGIN
                        --Start changes v16.1
                        IF ln_blk_cnt > 0
                        THEN
                            ld_req_ship_date   :=
                                c_line.latest_acceptable_date;
                        ELSE
                            ld_req_ship_date   := c_line.request_date;
                        END IF;

                        --End changes v16.1
                        apps.xxd_edi870_atp_pkg.get_atp_val_prc (
                            x_atp_qty,
                            v_msg_data,
                            v_err_code,
                            c_line.inventory_item_id,
                            c_line.ship_from_org_id,
                            c_line.order_quantity_uom,
                            c_line.ship_from_org_id,
                            c_line.ordered_quantity,
                            ld_req_ship_date,    --c_line.request_date --v16.1
                            c_line.demand_class_code,
                            x_req_date_qty,
                            x_available_date);
                        write_to_table ('ATP Quantity', x_atp_qty);

                        IF x_atp_qty = 0                  -- W.r.t Version 5.0
                        THEN
                            x_atp_qty   := x_req_date_qty;
                        END IF;

                        ln_line_qnty   := c_line.ordered_quantity - x_atp_qty;

                        write_to_table ('Line Quantity', ln_line_qnty);

                        IF     ln_line_qnty < c_line.ordered_quantity
                           AND ln_line_qnty > 0
                        THEN
                            --COMMIT;-----9.0 Commented as part of CCR0005906
                            l_split_line_total   := l_split_line_total + 1;

                            apps.do_oe_utils.split_line (p_line_id => c_line.line_id, p_new_line_quantity => ln_line_qnty, p_change_reason => 'PRD-0030', p_change_comments => 'Split due to insufficient product availability.', x_split_line_id => l_split_line_id, x_org_line_quantity => l_org_line_quantity, x_split_line_quantity => l_split_line_quantity, x_error_text => l_error_text, p_debug_location => NULL
                                                         , p_do_commit => 1);
                            COMMIT;
                        END IF;

                        write_to_table ('Split Line Id', l_split_line_id);
                        write_to_table ('Unable to split line. Error :: ',
                                        l_error_text);

                        IF l_split_line_id IS NOT NULL
                        THEN
                            l_split_line_cnt   := l_split_line_cnt + 1;
                            apps.do_oe_utils.schedule_line (
                                p_line_id              => c_line.line_id,
                                p_do_commit            => 0,
                                x_schedule_ship_date   => l_ssd);
                        ELSE
                            do_debug_tools.msg (
                                   'Unable to split line '
                                || c_line.line_id
                                || ' Error Text:'
                                || l_error_text);
                        END IF;
                    EXCEPTION
                        WHEN VALUE_ERROR
                        THEN
                            do_debug_tools.msg (
                                   'Unhandled exception in function '
                                || l_proc_name
                                || '-'
                                || SQLERRM);
                            write_to_table (
                                'Unhandled exception fetching ATP ',
                                SQLERRM);
                    END;
                END IF;
            END LOOP;

            IF ln_blk_cnt <= 0
            THEN                                                       --v16.1
                IF l_split_line_total > 0
                THEN
                    apps.do_order_hold_process.apply_order_hold (
                        p_header_id   => l_header_id,
                        p_line_id     => NULL,
                        p_hold_id     => l_hold_id,
                        p_comments    => NULL);
                --COMMIT;-----9.0 Commented as part of CCR0005906
                ELSE
                    do_debug_tools.msg ('No lines to split');
                    write_to_table ('No Lines to Split', l_header_id);
                END IF;
            END IF;                                         --ln_blk_cnt v16.1
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            do_debug_tools.msg (
                   'Unhandled exception in function '
                || l_proc_name
                || '-'
                || SQLERRM);
            write_to_table (
                'Unhandled exception in function  :: xxdo_edi_amzn_split_line',
                SQLERRM);
    END xxdo_edi_amzn_split_line;

    -- End of Amazon Split Line

    FUNCTION xxdo_oe_apply_hold (p_hold_id oe_hold_sources_all.hold_id%TYPE, p_header_id oe_order_headers.header_id%TYPE, p_user_id fnd_user.user_id%TYPE:= 0
                                 , p_resp_id fnd_responsibility.responsibility_id%TYPE:= 0, p_appl_id fnd_application.application_id%TYPE:= 0)
        RETURN NUMBER
    IS
        l_return_status     VARCHAR2 (30) := NULL;
        l_msg_data          VARCHAR2 (256) := NULL;
        l_msg_count         NUMBER := NULL;
        l_hold_source_rec   oe_holds_pvt.hold_source_rec_type;
        l_return            NUMBER := 0;
        l_user_id           NUMBER := NULL;
        l_resp_id           NUMBER := NULL;
        l_appl_id           NUMBER := NULL;
        l_mo_op_unit        VARCHAR2 (256) := 'MO: Operating Unit';
    BEGIN
        IF p_user_id <> 0 AND p_resp_id <> 0 AND p_appl_id <> 0
        THEN
            fnd_global.apps_initialize (p_user_id, p_resp_id, p_appl_id,
                                        0);
            mo_global.init ('ONT');
        END IF;

        write_to_table ('xxdo_oe_apply_hold ', p_hold_id);

        BEGIN
            SELECT user_id
              INTO l_user_id
              FROM fnd_user
             WHERE user_name = fnd_profile.VALUE ('XXDO_ADMIN_USER');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_user_id   := NULL;
        END;

        /* --Start W.r.t Version 6.0
        BEGIN
           SELECT application_id, responsibility_id
             INTO l_appl_id, l_resp_id
             FROM fnd_responsibility_tl
            WHERE responsibility_name =
                              fnd_profile.VALUE ('XXDO_EDI_HOLD_RESPONSIBILITY')
              --'Deckers Order Management User - US' Modified Mar 23rd for SIT Issue
              AND LANGUAGE = 'US';
        EXCEPTION
           WHEN OTHERS
           THEN
              do_debug_tools.msg
                            (   'Responsibility or Application does not exists'
                             || 'Deckers Order Management User - US'
                             || '-'
                             || SQLERRM
                            );
        END;
        */

        BEGIN
            SELECT frt.application_id, frt.responsibility_id
              INTO l_appl_id, l_resp_id
              FROM fnd_profile_option_values fpv, fnd_profile_options_vl fpo, oe_hold_authorizations oha,
                   fnd_responsibility_tl frt
             WHERE     1 = 1
                   AND fpv.profile_option_id = fpo.profile_option_id
                   AND fpo.user_profile_option_name = l_mo_op_unit
                   AND oha.responsibility_id = fpv.level_value
                   AND oha.responsibility_id = frt.responsibility_id
                   AND fpv.profile_option_value = g_op_unit
                   AND oha.hold_id = p_hold_id
                   AND oha.authorized_action_code = 'APPLY'
                   --AND frt.LANGUAGE ='US'
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (
                       'Responsibility or Application not Found'
                    || ' For OU '
                    || g_op_unit
                    || '-'
                    || SQLERRM);
                l_appl_id   := NULL;
                l_resp_id   := NULL;
        END;

        --End W.r.t Version 6.0
        write_to_table ('Pricing Hold l_appl_id ', l_appl_id);
        write_to_table ('Pricing Hold l_resp_id ', l_resp_id);

        fnd_global.apps_initialize (l_user_id, l_resp_id, l_appl_id);
        mo_global.init ('ONT');
        l_hold_source_rec                    := oe_holds_pvt.g_miss_hold_source_rec;
        l_hold_source_rec.hold_id            := p_hold_id;          -- hold_id
        l_hold_source_rec.hold_entity_code   := 'O';       -- order level hold
        l_hold_source_rec.hold_entity_id     := p_header_id;
        -- header_id of the order
        l_hold_source_rec.header_id          := p_header_id; -- header_id of the order
        oe_holds_pub.apply_holds (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_none,
            p_hold_source_rec    => l_hold_source_rec,
            x_return_status      => l_return_status,
            x_msg_count          => l_msg_count,
            x_msg_data           => l_msg_data);

        --COMMIT;-----9.0 Commented as part of CCR0005906

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            l_return   := 1;
        ELSE
            l_return   := 0;
            write_to_table ('Pricing Hold API Error Count', l_msg_count);

            FOR i IN 1 .. l_msg_count
            LOOP
                write_to_table ('Pricing Hold API Error', l_msg_data);
            END LOOP;
        END IF;

        write_to_table ('Return', l_return);
        RETURN l_return;
    END;

    PROCEDURE xxdo_ont_applyhold_fnc (
        p_order_number IN oe_order_headers_all.order_number%TYPE)
    IS
        l_local           NUMBER (6) := NULL;
        l_hold_id         oe_hold_definitions.hold_id%TYPE := NULL;
        l_header_id       oe_order_headers_all.header_id%TYPE := NULL;
        l_hold_required   NUMBER := 0;
    BEGIN
        BEGIN
              SELECT ooha.header_id, COUNT (oola.line_id), ooha.org_id
                INTO l_header_id, l_hold_required, g_op_unit
                FROM oe_order_lines_all oola, oe_order_headers_all ooha, oe_order_sources oos
               WHERE     oola.header_id = ooha.header_id
                     AND ooha.order_source_id = oos.order_source_id
                     ----------------------------------------------------------------------------
                     -- Commented By Sivakumar Boothathan to accomodate price difference hold
                     ----------------------------------------------------------------------------
                     --          AND NVL (oola.attribute13, '-1') <>
                     --                                 TO_CHAR (NVL (oola.unit_selling_price, '-1'))
                     ----------------------------------------------------------------------------------
                     -- End of commenting By Sivakumar Boothathan to accomodate price difference hold
                     ----------------------------------------------------------------------------------
                     ----------------------------------------------------------------------------------
                     -- Changes to accomodate the price difference hold scenario and also the buffer
                     ----------------------------------------------------------------------------------
                     AND ABS (
                             (NVL (oola.attribute13, '-1') - (NVL (oola.unit_selling_price, '-1')))) >
                         (SELECT tag
                            FROM apps.fnd_lookup_values
                           WHERE     language = 'US'
                                 AND lookup_type =
                                     'XXDO_PRICE_DIFFERENCE_BUFFER'
                                 AND lookup_code = ooha.org_id)
                     ---------------------------------------------------------------------------------------
                     -- End of changes By Sivakumar Boothathan to accomodate price difference hold
                     ---------------------------------------------------------------------------------------
                     AND oos.name = 'EDI'
                     AND ooha.order_number = p_order_number
            GROUP BY ooha.header_id, ooha.org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_hold_required   := 0;
        END;

        IF l_hold_required > 0
        THEN
            BEGIN
                SELECT hold_id
                  INTO l_hold_id
                  FROM oe_hold_definitions
                 WHERE hold_id =
                       fnd_profile.VALUE ('DO_PRICE_DIFF_HOLD_NAME');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hold_id   := NULL;
            END;

            IF l_hold_id IS NOT NULL
            THEN
                l_local   := xxdo_oe_apply_hold (l_hold_id, l_header_id);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20002,
                   'Error during apply hold for order number : '
                || p_order_number);
    END;

    FUNCTION edi_order_book_event (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        out_guid                  RAW (16);
        to_guid                   RAW (16);
        wftype                    VARCHAR2 (30);
        wfname                    VARCHAR2 (30);
        res                       VARCHAR2 (30);
        pri                       NUMBER;
        ikey                      VARCHAR2 (240);
        lparamlist                wf_parameter_list_t;
        subparams                 VARCHAR2 (4000);
        lcorrid                   VARCHAR2 (240);
        x_order_source            VARCHAR2 (240) := 'BLANK';
        x_order_source_id         NUMBER;
        x_org_id                  NUMBER;
        x_brand                   VARCHAR2 (500);
        x_sold_to_org_id          NUMBER;
        x_last_update_date        VARCHAR2 (100);
        x_orig_sys_document_ref   VARCHAR2 (50);
        x_customer_po_number      VARCHAR2 (50);
        x_order_number            VARCHAR2 (50);
        x_acct_num                VARCHAR2 (50);
        ln_855_cust_cnt           NUMBER;                         --CCR0006735
        lv_party_name             VARCHAR2 (150);
        msg                       VARCHAR2 (50);
        --
        l_ret                     NUMBER;
    --
    BEGIN
        do_debug_tools.msg (
            'Order booked Subscription Key: ' || p_event.event_data);
        write_to_table ('Order booked Subscription Key ',
                        p_subscription_guid);
        x_order_number   := p_event.event_data;
        write_to_table ('Order Number', x_order_number);


          SELECT COUNT (1), party_name
            INTO ln_855_cust_cnt, lv_party_name
            FROM oe_order_headers_all ooh, hz_cust_accounts hca, fnd_lookup_values_vl flv,
                 apps.hz_parties hp
           WHERE     1 = 1
                 AND party_name = meaning
                 AND hp.party_id = hca.party_id
                 AND enabled_flag = 'Y'
                 AND ooh.sold_to_org_id = hca.cust_account_id
                 AND lookup_type = 'XXD_EDI_855_CUSTOMERS'
                 AND order_number = x_order_number
                 AND NOT EXISTS
                         ((SELECT 'Y'
                             FROM fnd_lookup_values_vl
                            WHERE     lookup_type = 'XXD_ONT_EDI_855_EXCLUSION'
                                  AND enabled_flag = 'Y'
                                  AND NVL (attribute2, hca.cust_account_id) =
                                      hca.cust_account_id
                                  AND ooh.order_type_id = attribute3) -- Added for ver 13.0
                                                                     )
        GROUP BY party_name;

        IF ln_855_cust_cnt <> 0
        THEN
            SELECT out_agent_guid, to_agent_guid, wf_process_type,
                   wf_process_name, priority, parameters
              INTO out_guid, to_guid, wftype, wfname,
                           pri, subparams
              FROM wf_event_subscriptions
             WHERE guid = p_subscription_guid;

            SELECT os.name, h.order_source_id, h.sold_to_org_id,
                   h.orig_sys_document_ref, h.cust_po_number, cust_acct.account_number,
                   --h.demand_class_code,           -- Commented by BT Team on 16 June 2015 V4.0
                   h.attribute5, -- Added   by BT Team on 16 June 2015 V4.0
                                 h.org_id, TO_CHAR (h.last_update_date, 'YYYY-MM-DD"T"HH24:MI:SS') last_update_date
              INTO x_order_source, x_order_source_id, x_sold_to_org_id, x_orig_sys_document_ref,
                                 x_customer_po_number, x_acct_num, x_brand,
                                 x_org_id, x_last_update_date
              FROM ont.oe_order_headers_all h, ont.oe_order_sources os, hz_cust_accounts cust_acct
             WHERE     order_number = x_order_number
                   AND h.order_source_id = os.order_source_id
                   AND h.sold_to_org_id = cust_account_id(+);

            BEGIN
                write_to_855_table (x_order_number,      -- W.r.t Version 11.0
                                                    x_customer_po_number, x_acct_num
                                    , lv_party_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_to_table (
                        'Order booked Subscription 855 processing Order',
                        x_order_number || SQLERRM);
                    wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                                     , p_subscription_guid);
                    wf_event.seterrorinfo (p_event, 'ERROR');
                    RETURN 'ERROR';
            END;

            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
        /*           --Start W.r.t Version 11.0

                 -- and exists (select null from fnd_lookup_values flv where flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS' and flv.lookup_code = cust_acct.account_number);

                 -- if x_order_source = 'EDI'  then
                 IF subparams IS NOT NULL
                 THEN
                    IF (wf_event_functions_pkg.subscriptionparameters (
                           p_string   => subparams,
                           p_key      => 'CORRELATION_ID') = 'UNIQUE')
                    THEN
                       SELECT wf_error_processes_s.NEXTVAL INTO lcorrid FROM DUAL;

                       lcorrid := p_event.event_key || '-' || lcorrid;
                       p_event.setcorrelationid (lcorrid);
                    END IF;
                 END IF;

                 p_event.event_key := x_order_number;
                 lparamlist := p_event.parameter_list;
                 wf_event.addparametertolist ('SUB_GUID',
                                              p_subscription_guid,
                                              lparamlist);
                 wf_event.addparametertolist ('ORDER_SOURCE',
                                              x_order_source,
                                              lparamlist);
                 wf_event.addparametertolist ('CUST_PO_NUMBER',
                                              x_customer_po_number,
                                              lparamlist);
                 wf_event.addparametertolist ('ORIG_SYS_DOC_REF',
                                              x_orig_sys_document_ref,
                                              lparamlist);
                 wf_event.addparametertolist ('CUST_ACCT_NUM',
                                              x_acct_num,
                                              lparamlist);
                 wf_event.addparametertolist ('BRAND', x_brand, lparamlist);
                 wf_event.addparametertolist ('ORG_ID', x_org_id, lparamlist);
                 wf_event.addparametertolist ('LAST_UPDATE_DATE',
                                              x_last_update_date,
                                              lparamlist);
                 p_event.parameter_list := lparamlist;

                 IF (out_guid IS NOT NULL)
                 THEN
                    p_event.from_agent := wf_event.newagent (out_guid);
                    p_event.to_agent := wf_event.newagent (to_guid);
                    p_event.priority := pri;
                    p_event.send_date := NVL (p_event.getsenddate (), SYSDATE);
                    wf_event.send (p_event);
                 END IF;

                 --write_to_table ('Order Number ',x_order_number);

                 --BEGIN
                 --   write_to_table ('Before xxdo_ont_applyhold_fnc ',x_order_number);
                 --   xxdo_ont_applyhold_fnc(x_order_number);  -- For EDI Pricing Hold
                 --EXCEPTION
                 --    WHEN OTHERS
                 --    THEN
                 --       do_Debug_tools.msg ('Error in Procedure xxdo_ont_applyhold_fnc for the Order Number : '
                 --                        || x_order_number
                 --                        || ' :: '
                 --                        || SQLERRM
                 --                          );
                 --END;

                 --BEGIN
                 --   xxdo_edi_amzn_split_line(x_order_number); -- For Amazon ATP Split Line
                 --EXCEPTION
                 --    WHEN OTHERS
                 --    THEN
                 --       do_Debug_tools.msg ('Error in Procedure xxdo_edi_amzn_split_line for the Order Number : '
                 --                        || x_order_number
                 --                        || ' :: '
                 --                        || SQLERRM
                 --                          );
                 --END;

                 --  end if;
                 RETURN 'SUCCESS';

                 */
        --W.r.t Version 11.0
        ELSE
            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;

    -- Start Added Another Subscription for Order Booked Business Event

    FUNCTION edi_order_prchold_amznsplit (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        out_guid                  RAW (16);
        to_guid                   RAW (16);
        wftype                    VARCHAR2 (30);
        wfname                    VARCHAR2 (30);
        res                       VARCHAR2 (30);
        pri                       NUMBER;
        ikey                      VARCHAR2 (240);
        lparamlist                wf_parameter_list_t;
        subparams                 VARCHAR2 (4000);
        lcorrid                   VARCHAR2 (240);
        x_order_source            VARCHAR2 (240) := 'BLANK';
        x_order_source_id         NUMBER;
        x_org_id                  NUMBER;
        x_brand                   VARCHAR2 (500);
        x_sold_to_org_id          NUMBER;
        x_last_update_date        VARCHAR2 (100);
        x_orig_sys_document_ref   VARCHAR2 (50);
        x_customer_po_number      VARCHAR2 (50);
        x_order_number            VARCHAR2 (50);
        x_acct_num                VARCHAR2 (50);
        msg                       VARCHAR2 (50);
        --
        l_ret                     NUMBER;
        ln_line_error_cnt         NUMBER := 0;      --W.r.t version CCR0005906
    --
    BEGIN
        do_debug_tools.msg (
            'Order book Subscription Key: ' || p_event.event_data);
        x_order_number   := p_event.event_data;

        write_to_table ('edi_order_prchold_amznsplits', x_order_number);

        BEGIN                                 --Start W.r.t version CCR0005906
            SELECT COUNT (1)
              INTO ln_line_error_cnt
              FROM (SELECT orig_sys_line_ref
                      FROM apps.oe_lines_iface_all ola, oe_order_headers_all oha
                     WHERE     ola.orig_sys_document_ref =
                               oha.orig_sys_document_ref
                           AND order_number = x_order_number
                    MINUS
                    SELECT orig_sys_line_ref
                      FROM apps.oe_order_lines_all ola, oe_order_headers_all oha
                     WHERE     ola.header_id = oha.header_id
                           AND order_number = x_order_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_line_error_cnt   := 0;
        END;

        write_to_table ('Line error records for order ' || x_order_number,
                        ln_line_error_cnt);     --End W.r.t version CCR0005906

        IF ln_line_error_cnt = 0           --Added IF W.r.t version CCR0005906
        THEN
            BEGIN
                xxdo_ont_applyhold_fnc (x_order_number); -- For EDI Pricing Hold
            EXCEPTION
                WHEN OTHERS
                THEN
                    do_debug_tools.msg (
                           'Error in Procedure xxdo_ont_applyhold_fnc for the Order Number : '
                        || x_order_number
                        || ' :: '
                        || SQLERRM);
            END;

            BEGIN
                xxdo_edi_amzn_split_line (x_order_number);
            -- For Amazon ATP Split Line
            EXCEPTION
                WHEN OTHERS
                THEN
                    do_debug_tools.msg (
                           'Error in Procedure xxdo_edi_amzn_split_line for the Order Number : '
                        || x_order_number
                        || ' :: '
                        || SQLERRM);
            END;
        END IF;                                     --W.r.t version CCR0005906

        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;

    -- End Added Another Subscription for Order Booked Business Event

    FUNCTION site_use_id_to_location (p_customer_number   VARCHAR2,
                                      p_site_uses_id      NUMBER)
        RETURN VARCHAR2
    IS
        l_proc_name     VARCHAR2 (240) := 'SITE_USE_ID_LOCATION_TO';
        x_location_id   VARCHAR2 (500);
        l_customer_id   NUMBER;
    BEGIN
        msg ('-' || lg_package_name || '.' || l_proc_name);

        -- Start for CCR0010148
        BEGIN
            SELECT customer_id
              INTO l_customer_id
              FROM apps.ra_hcustomers rac
             WHERE rac.customer_number = p_customer_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_customer_id   := NULL;
                msg (
                       'Unable to derive customer id for : '
                    || p_customer_number);
        END;

        -- End for CCR0010148
        SELECT rsua.location
          INTO x_location_id
          FROM                     /* ra_site_uses_all -- Changed by Prasad */
               apps.ra_site_uses_morg rsua, /* ra_addresses_all -- Changed by Prasad */
                                            apps.ra_addresses_morg raa, /* ra_customers -- Changed by Prasad */
                                                                        apps.ra_hcustomers rac
         WHERE --rac.customer_number = p_customer_number --Comment for CCR0010148
                   rac.customer_id = l_customer_id     -- Added for CCR0010148
               AND raa.customer_id = rac.customer_id
               AND raa.status = 'A'
               AND rsua.address_id = raa.address_id
               AND rsua.status = 'A'
               AND rsua.site_use_id = p_site_uses_id;

        msg (
               'Function '
            || l_proc_name
            || ' returning ('
            || x_location_id
            || ')');
        msg ('-' || lg_package_name || '.' || l_proc_name);
        RETURN x_location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || lg_package_name
                || '.'
                || l_proc_name);
            msg ('-' || lg_package_name || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION edi_dock_door_closed_event (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        out_guid            RAW (16);
        to_guid             RAW (16);
        wftype              VARCHAR2 (30);
        wfname              VARCHAR2 (30);
        res                 VARCHAR2 (30);
        pri                 NUMBER;
        ikey                VARCHAR2 (240);
        lparamlist          wf_parameter_list_t;
        subparams           VARCHAR2 (4000);
        lcorrid             VARCHAR2 (240);
        x_shipment_id       NUMBER;
        x_customer_number   VARCHAR2 (100);
        x_edi_flag          NUMBER;
        msg                 VARCHAR2 (50);
    BEGIN
        do_debug_tools.msg (
            'Dock door closed Subscription Key: ' || p_event.event_key);
        x_edi_flag   := 0;

        --  select customer_number
        --  into x_customer_number
        --  from do_custom.do_edi856out_headers_v ship_hdr
        --  where ship_hdr.shipment_id = p_event.event_key;
        SELECT rac.customer_number
          INTO x_customer_number
          FROM do_edi.do_edi856_shipments ship_hdr, ra_hcustomers rac
         ---- Changes for BT Technology Team for BT on 14-Nov-2014 : Changed: ra_customers -->  ra_hcustomers
         WHERE     ship_hdr.shipment_id = p_event.event_key
               AND rac.customer_id = ship_hdr.customer_id;


        IF is_edi_customer (x_customer_number, '856') = 'Y'
        THEN
            SELECT out_agent_guid, to_agent_guid, wf_process_type,
                   wf_process_name, priority, parameters
              INTO out_guid, to_guid, wftype, wfname,
                           pri, subparams
              FROM wf_event_subscriptions
             WHERE guid = p_subscription_guid;

            IF subparams IS NOT NULL
            THEN
                IF (wf_event_functions_pkg.subscriptionparameters (p_string => subparams, p_key => 'CORRELATION_ID') = 'UNIQUE')
                THEN
                    SELECT wf_error_processes_s.NEXTVAL
                      INTO lcorrid
                      FROM DUAL;

                    lcorrid   := p_event.event_key || '-' || lcorrid;
                    p_event.setcorrelationid (lcorrid);
                END IF;
            END IF;

            lparamlist               := p_event.parameter_list;
            wf_event.addparametertolist ('SUB_GUID',
                                         p_subscription_guid,
                                         lparamlist);
            wf_event.addparametertolist ('CUST_ACCT_NUM',
                                         x_customer_number,
                                         lparamlist);
            p_event.parameter_list   := lparamlist;

            IF (out_guid IS NOT NULL)
            THEN
                p_event.from_agent   := wf_event.newagent (out_guid);
                p_event.to_agent     := wf_event.newagent (to_guid);
                p_event.priority     := pri;
                p_event.send_date    := NVL (p_event.getsenddate (), SYSDATE);
                wf_event.send (p_event);
            END IF;
        END IF;

        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END;

    /*****************************************************
        --added this Function w.r.t to CCR0009477
    Function: xxd_shopify_asn_event
       Parameters:
       p_subscription_guid: event data
    p_event:wf_event_t
       Purpose: populate the bpel queue for DXLAB ASN
     *****************************************************/

    FUNCTION xxd_shopify_asn_event (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2
    IS
        out_guid            RAW (16);
        to_guid             RAW (16);
        wftype              VARCHAR2 (30);
        wfname              VARCHAR2 (30);
        res                 VARCHAR2 (30);
        pri                 NUMBER;
        ikey                VARCHAR2 (240);
        lparamlist          wf_parameter_list_t;
        subparams           VARCHAR2 (4000);
        lcorrid             VARCHAR2 (240);
        x_shipment_id       NUMBER;
        x_customer_number   VARCHAR2 (100);
        x_edi_flag          NUMBER;
        msg                 VARCHAR2 (50);
    BEGIN
        do_debug_tools.msg (
            'Dock door closed Subscription Key: ' || p_event.event_key);
        x_edi_flag               := 0;

        SELECT rac.customer_number
          INTO x_customer_number
          FROM do_edi.do_edi856_shipments ship_hdr, ra_hcustomers rac
         ---- Changes for BT Technology Team for BT on 14-Nov-2014 : Changed: ra_customers -->  ra_hcustomers
         WHERE     ship_hdr.shipment_id = p_event.event_key
               AND rac.customer_id = ship_hdr.customer_id;

        SELECT out_agent_guid, to_agent_guid, wf_process_type,
               wf_process_name, priority, parameters
          INTO out_guid, to_guid, wftype, wfname,
                       pri, subparams
          FROM wf_event_subscriptions
         WHERE guid = p_subscription_guid;

        IF subparams IS NOT NULL
        THEN
            IF (wf_event_functions_pkg.subscriptionparameters (p_string => subparams, p_key => 'CORRELATION_ID') = 'UNIQUE')
            THEN
                SELECT wf_error_processes_s.NEXTVAL INTO lcorrid FROM DUAL;

                lcorrid   := p_event.event_key || '-' || lcorrid;
                p_event.setcorrelationid (lcorrid);
            END IF;
        END IF;

        lparamlist               := p_event.parameter_list;
        wf_event.addparametertolist ('SUB_GUID',
                                     p_subscription_guid,
                                     lparamlist);
        wf_event.addparametertolist ('CUST_ACCT_NUM',
                                     x_customer_number,
                                     lparamlist);
        p_event.parameter_list   := lparamlist;

        IF (out_guid IS NOT NULL)
        THEN
            p_event.from_agent   := wf_event.newagent (out_guid);
            p_event.to_agent     := wf_event.newagent (to_guid);
            p_event.priority     := pri;
            p_event.send_date    := NVL (p_event.getsenddate (), SYSDATE);
            wf_event.send (p_event);
        END IF;

        RETURN 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('Wf_Rule', 'Default_Rule', p_event.geteventname ()
                             , p_subscription_guid);
            wf_event.seterrorinfo (p_event, 'ERROR');
            RETURN 'ERROR';
    END xxd_shopify_asn_event;

    FUNCTION delivery_ship_weight (p_delivery_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER;
    BEGIN
        /*
             select sum(net_weight)
             into l_ret
             from wsh_delivery_details wdd,
                  wsh_delivery_assignments wda
             where wda.delivery_id = p_delivery_id
               and wdd.delivery_detail_id = wda.delivery_detail_id
               and wdd.source_code = 'WSH'
               and wdd.container_flag = 'Y';

             if l_ret is null then
             */
        SELECT SUM (NVL (msib.unit_weight, 2) * wdd.shipped_quantity)
          INTO l_ret
          FROM mtl_system_items_b msib, wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND msib.organization_id = wdd.organization_id
               AND msib.inventory_item_id = wdd.inventory_item_id
               AND wdd.source_code = 'OE';

        --end if;
        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /*****************************************************
         Procedure: DELIVERY_CONTAINER_COUNT
         Parameters:
           p_delivery_id: Delivery ID
         Purpose: Returns the # of containers for a given
                    Delivery ID.
       *****************************************************/

    FUNCTION delivery_container_count (p_delivery_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO l_ret
          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.source_code = 'WSH'
               AND wdd.container_flag = 'Y'
               AND EXISTS
                       (SELECT NULL
                          FROM wsh.wsh_delivery_details item, wsh.wsh_delivery_assignments cont
                         WHERE     cont.delivery_detail_id =
                                   item.delivery_detail_id
                               AND cont.parent_delivery_detail_id =
                                   wdd.delivery_detail_id
                               AND item.container_flag = 'N');

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /*****************************************************
         Procedure: DELIVERY_SHIP_VOLUME
         Parameters:
           p_delivery_id: Delivery ID
         Purpose: Returns the shipped volume for a given
                    Delivery ID.
       *****************************************************/

    FUNCTION delivery_ship_volume (p_delivery_id IN NUMBER)
        RETURN NUMBER
    IS
        l_ret   NUMBER;
    BEGIN
        SELECT SUM (volume)
          INTO l_ret
          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.source_code = 'WSH'
               AND wdd.container_flag = 'Y';

        IF l_ret IS NULL
        THEN
            SELECT SUM (NVL (msib.unit_volume, 385) * wdd.shipped_quantity)
              INTO l_ret
              FROM mtl_system_items_b msib, wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wda.delivery_id = p_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND msib.organization_id = wdd.organization_id
                   AND msib.inventory_item_id = wdd.inventory_item_id
                   AND wdd.source_code = 'OE';
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    -- Function to fetch concatenated VAS codes of the customer -- Added by Lakshmi BTDEV Team on 10-FEB-2015

    FUNCTION get_vas_codes (
        p_cust_number hz_cust_accounts.account_number%TYPE)
        RETURN VARCHAR2
    IS
        l_vas_codes   VARCHAR2 (4000) := NULL;
        l_loop_cnt    NUMBER := 0;

        CURSOR c_fetch_vas_codes IS
            SELECT title
              FROM oe_attachment_rule_elements_v oarev, oe_attachment_rules_v oarv, fnd_documents_vl fdv
             WHERE     oarv.document_id = fdv.document_id
                   AND oarev.rule_id = oarv.rule_id
                   AND fdv.category_description = 'VAS Codes'
                   AND attribute_value =
                       (SELECT apps.xxdo_edi_utils_pub.customer_number_to_customer_id (p_cust_number) FROM DUAL);
    BEGIN
        l_loop_cnt   := 0;

        FOR r_fetch_vas_codes IN c_fetch_vas_codes
        LOOP
            IF l_loop_cnt = 0
            THEN
                l_vas_codes   := r_fetch_vas_codes.title;
            ELSIF l_loop_cnt > 0
            THEN
                l_vas_codes   :=
                    l_vas_codes || '+' || r_fetch_vas_codes.title;
            END IF;

            EXIT WHEN LENGTH (l_vas_codes) > 240;
            l_loop_cnt   := l_loop_cnt + 1;
        END LOOP;

        RETURN SUBSTR (l_vas_codes, 1, 240);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /*
       PROCEDURE default_hsoe_headers (p_document_ref IN VARCHAR2)
       IS
          l_brand             VARCHAR2 (240);
          l_customer_id       NUMBER;
          l_order_type_id     NUMBER;
          l_order_source_id   NUMBER;
          l_bill_to_org_id    NUMBER;
          l_ship_to_org_id    NUMBER;
          l_order_curr        do_get_order_defaults.ref_cursor;
          l_def_rec           do_get_order_defaults.return_rec;
          l_rid               ROWID;
          l_request_date      DATE;
       BEGIN
          SELECT attribute5 brand,
                 a.sold_to_org_id customer_id,
                 a.order_type_id,
                 a.order_source_id,
                 a.invoice_to_org_id bill_to_org_id,
                 a.ship_to_org_id,
                 a.request_date,
                 ROWID
            INTO l_brand,
                 l_customer_id,
                 l_order_type_id,
                 l_order_source_id,
                 l_bill_to_org_id,
                 l_ship_to_org_id,
                 l_request_date,
                 l_rid
            FROM HSOE.OE_HEADERS_IFACE_ALL a
           WHERE orig_sys_document_ref = p_document_ref;

          do_get_order_defaults.order_info (
             ORDER_CUR           => l_order_curr,
             V_BRAND             => l_brand,
             L_CUSTOMER_ID       => l_customer_id,
             L_ORDER_TYPE_ID     => l_order_type_id,
             L_ORDER_SOURCE_ID   => l_order_source_id,
             L_BILL_TO_ORG_ID    => l_bill_to_org_id,
             L_SHIP_TO_ORG_ID    => l_ship_to_org_id);

          IF l_order_curr%ISOPEN
          THEN
             FETCH l_order_curr INTO l_def_rec;

             UPDATE hsoe.oe_headers_iface_all
                SET price_list_id = NVL (price_list_id, l_def_rec.price_list_id),
                    payment_term_id =
                       NVL (payment_term_id, l_def_rec.payment_term_id),
                    shipping_method_code =
                       NVL (shipping_method_code, l_def_rec.shipping_method_code),
                    freight_terms_code =
                       NVL (freight_terms_code, l_def_rec.freight_terms_code),
                    invoice_to_org_id =
                       NVL (invoice_to_org_id, l_def_rec.invoice_to_org_id),
                    shipping_instructions =
                       NVL (shipping_instructions,
                            l_def_rec.shipping_instructions),
                    packing_instructions =
                       NVL (packing_instructions, l_def_rec.packing_instructions),
                    fob_point_code =
                       NVL (fob_point_code, l_def_rec.fob_point_code),
                    ship_from_org_id =
                       NVL (ship_from_org_id, l_def_rec.ship_from_org_id),
                    booked_flag = 'N',
                    salesrep_id =
                       NVL (salesrep_id,
                            DO_CUSTOM.DO_GET_SALESREP_ID (
                               l_customer_id,
                               NVL (invoice_to_org_id,
                                    l_def_rec.invoice_to_org_id),
                               NVL (ship_to_org_id, l_def_rec.ship_to_org_id),
                               l_brand))
              WHERE ROWID = l_rid;

             CLOSE l_order_curr;
          END IF;

          UPDATE hsoe.oe_lines_iface_all
             SET request_date = NVL (request_date, l_request_date)
           WHERE orig_sys_document_ref = p_document_ref;

          UPDATE hsoe.OE_PRICE_ADJS_IFACE_ALL opail
             SET adjusted_amount =
                    NVL (
                       opail.adjusted_amount,
                       NVL (
                          (SELECT ABS (
                                       olia.unit_list_price
                                     - olia.unit_selling_price)
                             FROM hsoe.oe_lines_iface_all olia
                            WHERE     olia.orig_sys_document_ref =
                                         opail.orig_sys_document_ref
                                  AND olia.orig_sys_line_ref =
                                         opail.orig_sys_line_ref),
                          0)),
                 adjusted_amount_per_pqty =
                    NVL (
                       opail.adjusted_amount,
                       NVL (
                          (SELECT ABS (
                                       olia.unit_list_price
                                     - olia.unit_selling_price)
                             FROM hsoe.oe_lines_iface_all olia
                            WHERE     olia.orig_sys_document_ref =
                                         opail.orig_sys_document_ref
                                  AND olia.orig_sys_line_ref =
                                         opail.orig_sys_line_ref),
                          0))
           WHERE opail.orig_sys_document_ref = p_document_ref;
       END;
    */
    -- Start changes for CCR0008173
    FUNCTION jp_get_order_type_id (p_additional_info IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_order_type (p_order_type VARCHAR2)
        IS
            SELECT tag
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_ONT_EDI_JPN_ORDER_TYPE'
                   AND language = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE))
                   AND lookup_code = p_order_type;

        ln_order_type_id   oe_transaction_types_tl.transaction_type_id%TYPE;
        lc_order_type      VARCHAR2 (50);
    BEGIN
        SELECT REGEXP_SUBSTR (p_additional_info, '[^;]+', 1,
                              2)
          INTO lc_order_type
          FROM DUAL;

        -- Check the lookup with the actual Value
        OPEN get_order_type (lc_order_type);

        FETCH get_order_type INTO ln_order_type_id;

        CLOSE get_order_type;

        -- If Null then Derive the DEFAULT Order Type
        IF ln_order_type_id IS NULL
        THEN
            lc_order_type   := 'DEFAULT';

            OPEN get_order_type (lc_order_type);

            FETCH get_order_type INTO ln_order_type_id;

            CLOSE get_order_type;
        END IF;

        RETURN ln_order_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END jp_get_order_type_id;

    -- End changes for CCR0008173
    -- Start changes for CCR0009023
    FUNCTION get_bill_to_site_id (p_customer_number IN VARCHAR2, p_org_id IN NUMBER, p_store_number IN VARCHAR2)
        RETURN NUMBER
    AS
        ln_site_use_id   NUMBER;
        l_customer_id    NUMBER;
    BEGIN
        --Start for CCR0010148
        BEGIN
            SELECT customer_id
              INTO l_customer_id
              FROM apps.ra_hcustomers rac
             WHERE rac.customer_number = p_customer_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_customer_id   := NULL;
                msg (
                       'Unable to derive customer id for : '
                    || p_customer_number);
        END;

        --End for CCR0010148
        BEGIN
            SELECT hcsua.site_use_id
              INTO ln_site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcasa, hz_cust_site_uses_all hcsua
             WHERE     hca.cust_account_id = hcasa.cust_account_id
                   AND hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
                   AND hcsua.site_use_code = 'BILL_TO'
                   AND hcasa.attribute2 = p_store_number
                   AND hcsua.org_id = p_org_id
                   --AND hca.account_number = p_customer_number--Comment for CCR0010148
                   AND hca.cust_account_id = l_customer_id; ---Added for CCR0010148
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_site_use_id   := NULL;
        END;

        RETURN ln_site_use_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_bill_to_site_id;
-- End changes for CCR0009023

BEGIN
    --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
    SELECT user_id
      INTO gn_user_id
      FROM fnd_user
     WHERE user_name = 'BATCH';

    SELECT user_id
      INTO gn_user_id1
      FROM fnd_user
     --WHERE user_name = 'BBURNS';
     WHERE user_name = 'BRIANB';

    SELECT responsibility_id
      INTO gn_resp_id
      FROM fnd_responsibility_vl
     -- WHERE responsibility_name = 'Order Management Super User - US';
     WHERE responsibility_name = 'Deckers Order Management User - US';

    -- Modified for 2.0;
    SELECT application_id
      INTO gn_appln_id
      FROM fnd_application_vl
     WHERE application_name = 'Deckers Custom Applications';

    --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
    SELECT COUNT (*)
      INTO g_n_temp
      FROM v$database
     WHERE name = 'PROD';

    IF NVL (fnd_global.user_id, -1) = -1
    THEN
        IF g_n_temp = 1 AND NVL (fnd_global.user_id, -1) = -1
        THEN                              -- if it's prod then log in as BATCH
            --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
            --(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_appln_id);
        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        --      fnd_global.apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);
        --fnd_global.initialize(l_buffer_number,1037,50225,20003,0,-1,-1,-1,-1,-1,666,-1);
        --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        /*
 --As mentioned in the FND_GLOBAL package header "INTERNAL AOL USE ONLY", so commenting this code.
                        fnd_global.initialize (l_buffer_number,
                        gn_user_id,
                        gn_resp_id,
                        gn_appln_id,
                        0,
                        -1,
                        -1,
                        -1,
                        -1,
                        -1,
                        666,
                        -1);
                        */
        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        ELSE                                     -- otherwise log in as BBURNS
            --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
            --do_apps_initialize(user_id => 1037,resp_id => 50225,resp_appl_id => 20003);
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_appln_id);
        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        --      fnd_global.apps_initialize(user_id => 1062,resp_id => 50225,resp_appl_id => 20003);
        --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        --fnd_global.initialize(l_buffer_number,1037,50225,20003,0,-1,-1,-1,-1,-1,666,-1);
                       /*
--As mentioned in the FND_GLOBAL package header "INTERNAL AOL USE ONLY", so commenting this code.
                       fnd_global.initialize (l_buffer_number,
                       gn_user_id1,
                       gn_resp_id,
                       gn_appln_id,
                       0,
                       -1,
                       -1,
                       -1,
                       -1,
                       -1,
                       666,
                       -1);*/
        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        END IF;

        fnd_file.put_names ('EDI_UTILS_' || USERENV ('SESSIONID') || '.log',
                            'EDI_UTILS_' || USERENV ('SESSIONID') || '.out',
                            '/usr/tmp');
    END IF;

    --Start Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
    --if fnd_global.user_id = 1062   then -- if BBURNS then crank up the debugging
    IF fnd_global.user_id = gn_user_id1
    THEN
        -- if BBURNS then crank up the debugging
        --End Changes by BT Technology Team for BT on 22-JUL-2014,  v1.0
        do_debug_tools.enable_table (10000000);
        fnd_profile.put ('DO_EDI_MAIL_DEBUG', 'Y');
        fnd_profile.put ('DO_EDI_MAIL_DEBUG_DETAIL', 'Y');
    END IF;

    IF g_mail_debugging_attach_debug
    THEN
        do_debug_tools.enable_table (10000000);
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        NULL;
END xxdo_edi_utils_pub;
/


--
-- XXDO_EDI_UTILS_PUB  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_EDI_UTILS_PUB FOR APPS.XXDO_EDI_UTILS_PUB
/


GRANT EXECUTE ON APPS.XXDO_EDI_UTILS_PUB TO SOA_INT
/
