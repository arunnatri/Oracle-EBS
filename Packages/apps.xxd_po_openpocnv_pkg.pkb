--
-- XXD_PO_OPENPOCNV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_OPENPOCNV_PKG"
AS
    -- +==============================================================================+
    -- +                      Deckers Oracle 12i                                      +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Name: BT Technology Team                                                      |
    -- |Creation Date: 18-AUG-2014                                                    |
    -- |Application Name:  Custom Application                                         |
    -- |Source File Name: XXD_PO_OPENPOCNV_PKG.pks                                    |
    -- |                                                                              |
    -- |Object Name :   XXD_PO_OPENPOCNV_PKG                                          |
    -- |Description   : The package Spac is defined to convert the                    |
    -- |                in R12                                                        |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |Parameters   :      p_action     -- Action Type                               |
    -- |                p_batch_cnt      -- Batch Count                               |
    -- |                p_batch_size     -- Batch Size                                |
    -- |                p_debug          -- Debug Flag                                |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                         |
    -- |=======   ==========  ===================   ============================      |
    -- |1.0       18-AUG-2014  BT Technology Team     Initial draft version           |
    -- +==============================================================================+
    PROCEDURE write_log (p_message IN VARCHAR2)
    -- +===================================================================+
    -- | Name  : WRITE_LOG                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+
    IS
    BEGIN
        IF gc_debug_flag = 'Y'
        THEN
            APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, p_message);
        END IF;
    END write_log;

    PROCEDURE write_out (p_message IN VARCHAR2)
    -- +===================================================================+
    -- | Name  : WRITE_OUT                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program output file                            |
    -- +===================================================================+
    IS
    BEGIN
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, p_message);
    END write_out;


    /*****************************************************************************************
     *  Procedure Name :   submit_conc_prc                                                   *
     *                                                                                       *
     *  Description    :   This Procedure shall Calls the standard  submit_request API       *
     *                     Submits concurrent request to be processed by a concurrent manager*
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  application                        Short name of application under which the program *
     *                                   is registered                                       *
     *  program                              concurrent program name for which the request has*
     *                                      to be submitted                                  *
     *  description                        Optional. Will be displayed along with user       *
     *                                      concurrent program name                          *
     *  start_time                          Optional. Time at which the request has to start *
     *                                      running                                          *
     *  sub_request                        Optional. Set to TRUE if the request is submitted *
     *                                          from another running request and has to be treated  *
     *                                      as a sub request. Default is FALSE               *
     *  argument1..100                      Optional. Arguments for the concurrent request   *
     *                                                                                       *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *****************************************************************************************/

    -- FND concurrent request launcher program.
    PROCEDURE submit_conc_prc (
        x_request_id       OUT NUMBER,
        x_status_code      OUT VARCHAR2,
        x_return_mesg      OUT VARCHAR2,
        p_application   IN     VARCHAR2,
        p_program       IN     VARCHAR2,
        p_description   IN     VARCHAR2,
        p_start_time    IN     VARCHAR2 DEFAULT NULL,
        p_sub_request   IN     BOOLEAN DEFAULT FALSE,
        p_argument1     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument2     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument3     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument4     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument5     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument6     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument7     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument8     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument9     IN     VARCHAR2 DEFAULT CHR (0),
        p_argument10    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument11    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument12    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument13    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument14    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument15    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument16    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument17    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument18    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument19    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument20    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument21    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument22    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument23    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument24    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument25    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument26    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument27    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument28    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument29    IN     VARCHAR2 DEFAULT CHR (0),
        p_argument30    IN     VARCHAR2 DEFAULT CHR (0))
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        ------------------------------------------------
        --Submit the request by calling the following API
        ------------------------------------------------
        x_request_id   :=
            fnd_request.submit_request (application   => p_application,
                                        program       => p_program,
                                        description   => p_description,
                                        start_time    => p_start_time,
                                        sub_request   => p_sub_request,
                                        argument1     => p_argument1,
                                        argument2     => p_argument2,
                                        argument3     => p_argument3,
                                        argument4     => p_argument4,
                                        argument5     => p_argument5,
                                        argument6     => p_argument6,
                                        argument7     => p_argument7,
                                        argument8     => p_argument8,
                                        argument9     => p_argument9,
                                        argument10    => p_argument10,
                                        argument11    => p_argument11,
                                        argument12    => p_argument12,
                                        argument13    => p_argument13,
                                        argument14    => p_argument14,
                                        argument15    => p_argument15,
                                        argument16    => p_argument16,
                                        argument17    => p_argument17,
                                        argument18    => p_argument18,
                                        argument19    => p_argument19,
                                        argument20    => p_argument20,
                                        argument21    => p_argument21,
                                        argument22    => p_argument22,
                                        argument23    => p_argument23,
                                        argument24    => p_argument24,
                                        argument25    => p_argument25,
                                        argument26    => p_argument26,
                                        argument27    => p_argument27,
                                        argument28    => p_argument28,
                                        argument29    => p_argument29,
                                        argument30    => p_argument30);

        IF NVL (x_request_id, 0) = 0
        THEN
            --Return from procedure with error code;
            x_status_code   := gn_err_const;
        ELSE
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status_code   := gn_err_const;
            x_return_mesg   := 'submit_conc_prc' || SQLERRM;
    END submit_conc_prc;

    FUNCTION check_currency (p_cur_code IN VARCHAR2)
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name  : CHECK_CURRENCY                                            |
    -- | Description      : This function  is used to check                |
    -- |                    currency code from EBS                         |
    -- |                                                                   |
    -- | Parameters : p_cur_code                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        lc_status   VARCHAR2 (1);
    BEGIN
        SELECT 'X'
          INTO lc_status
          FROM SYS.DUAL
         WHERE EXISTS
                   (SELECT currency_code
                      FROM fnd_currencies
                     WHERE UPPER (currency_code) = UPPER (p_cur_code));

        RETURN lc_status;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'Y';
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error (
                  'PO',
                  gn_org_id,
                  'XXD Open Purchase Orders Conversion Program',
                  --      SQLCODE,
                  SQLERRM,
                  DBMS_UTILITY.format_error_backtrace,
                  --   DBMS_UTILITY.format_call_stack,
                  --    SYSDATE,
                  gn_user_id,
                  gn_conc_request_id,
                  'CHECK_CURRENCY',
                  p_cur_code,
                  'Exception to CHECK_CURRENCY Procedure' || SQLERRM);

               write_log (
                     'Exception Of XXBIC_PO_OPENPOCNV_PKG.CHECK_CURRENCY Procedure'
                  || SQLERRM); */
            NULL;
    END check_currency;

    PROCEDURE get_org_id (p_org_name IN VARCHAR2, x_org_id OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    BEGIN
        px_meaning   := p_org_name;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (NAME) = UPPER (x_attribute1);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*         xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'GET_ORG_ID',
                        p_org_name,
                        'Exception to GET_ORG_ID Procedure' || SQLERRM);
                     write_log ('Exception to GET_ORG_ID Procedure' || SQLERRM); */
            NULL;
    END get_org_id;



    PROCEDURE get_1206_org_id (p_org_name   IN            VARCHAR2,
                               x_org_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    BEGIN
        px_meaning   := p_org_name;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        x_org_id     := px_lookup_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*         xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'GET_ORG_ID',
                        p_org_name,
                        'Exception to GET_ORG_ID Procedure' || SQLERRM);
                     write_log ('Exception to GET_ORG_ID Procedure' || SQLERRM); */
            NULL;
    END get_1206_org_id;


    PROCEDURE get_ship_to_loc_id (p_loc_name IN VARCHAR2, p_bill_ship_to IN VARCHAR2, x_loc_id OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_loc_name, p_bill_ship_to ,p_request_id             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loc_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT hla.location_id
          INTO x_loc_id
          FROM hr_locations_all hla
         WHERE     UPPER (hla.location_code) = UPPER (p_loc_name)
               --AND hla.inventory_organization_id = p_org_id
               AND ((p_bill_ship_to = 'BILL_TO' AND hla.bill_to_site_flag = 'Y') OR (p_bill_ship_to = 'SHIP_TO' AND hla.ship_to_site_flag = 'Y'))
               AND NVL (hla.inactive_date, TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*    xxd_common_utils.record_error (
                   'PO',
                   gn_org_id,
                   'XXD Open Purchase Orders Conversion Program',
                   --      SQLCODE,
                   'Exception to GET_SHIP_TO_LOC_ID Procedure' || SQLERRM,
                   DBMS_UTILITY.format_error_backtrace,
                   --   DBMS_UTILITY.format_call_stack,
                   --    SYSDATE,
                   gn_user_id,
                   gn_conc_request_id,
                   'GET_SHIP_TO_LOC_ID',
                   p_loc_name);
                write_log ('Exception to GET_SHIP_TO_LOC_ID Procedure' || SQLERRM); */
            NULL;
    END get_ship_to_loc_id;

    --------------------------------
    PROCEDURE get_ship_to_locat_id (
        p_ship_to_org_id   IN            VARCHAR2,
        x_loctn_id            OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_LOC_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_ship_to_org_id, p_bill_ship_to ,p_request_id        |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loctn_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT hou.location_id
          INTO x_loctn_id
          FROM hr_organization_units hou, hr_locations_all hll
         WHERE     hou.organization_id = p_ship_to_org_id
               AND hou.location_id = hll.location_id
               AND hll.ship_to_site_flag = 'Y'
               AND NVL (hll.inactive_date, TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_ship_to_locat_id;

    PROCEDURE get_bill_to_locat_id (p_vend_site_id   IN            VARCHAR2,
                                    x_loctn_id          OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_BILL_TO_LOCAT_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    bill to loc id from EBS                        |
    -- |                                                                   |
    -- | Parameters : p_ship_to_org_id, p_bill_ship_to ,p_request_id        |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_loctn_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT bill_to_location_id
          INTO x_loctn_id
          FROM ap_supplier_sites_all assa
         WHERE assa.vendor_site_id = p_vend_site_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_log (
                'No bill_to_location_id corresponding to this Vendor Site ID');
        WHEN OTHERS
        THEN
            NULL;
    END get_bill_to_locat_id;

    --------------------------------

    PROCEDURE get_terms_id (p_terms_name   IN            VARCHAR2,
                            x_terms_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_TERMS_ID                                              |
    -- | Description      : This procedure  is used to get                 |
    -- |                    terms id from EBS                              |
    -- |                                                                   |
    -- | Parameters : p_terms_name                                         |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_terms_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT att.term_id
          INTO x_terms_id
          FROM ap_terms_tl att
         WHERE     UPPER (att.NAME) = UPPER (p_terms_name)
               AND NVL (enabled_flag, 'N') = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date_active),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (end_date_active),
                                                TRUNC (SYSDATE))
               AND att.LANGUAGE = USERENV ('LANG');
    EXCEPTION
        WHEN OTHERS
        THEN
            /* xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_TERMS_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_TERMS_ID',
                p_terms_name);
             write_log ('Exception to GET_TERMS_ID Procedure' || SQLERRM); */
            NULL;
    END get_terms_id;

    PROCEDURE GET_AGENT_ID (p_buyer_name   IN            VARCHAR2,
                            x_agent_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_AGENT_ID                                              |
    -- | Description      : This procedure  is used to get                 |
    -- |                    agent id from EBS                              |
    -- |                                                                   |
    -- | Parameters : p_buyer_name                                         |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_agent_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT papf.person_id
          INTO x_agent_id
          FROM per_all_people_f papf, po_agents pa
         WHERE     TRUNC (SYSDATE) BETWEEN NVL (TRUNC (effective_start_date),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (effective_end_date),
                                                TRUNC (SYSDATE))
               AND pa.agent_id = papf.person_id
               AND (UPPER (papf.full_name) = UPPER (p_buyer_name) OR UPPER (papf.full_name) = UPPER ('Stewart, Celene'))
               AND ROWNUM = 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*        xxd_common_utils.record_error (
                       'PO',
                       gn_org_id,
                       'XXD Open Purchase Orders Conversion Program',
                       --      SQLCODE,
                       'Exception to GET_AGENT_ID Procedure' || SQLERRM,
                       DBMS_UTILITY.format_error_backtrace,
                       --   DBMS_UTILITY.format_call_stack,
                       --    SYSDATE,
                       gn_user_id,
                       gn_conc_request_id,
                       'GET_AGENT_ID',
                       p_buyer_name);
                    write_log ('Exception to GET_AGENT_ID Procedure' || SQLERRM); */
            NULL;
    END GET_AGENT_ID;

    PROCEDURE GET_VENDOR_ID (p_vendor_num   IN            VARCHAR2,
                             x_vendor_id       OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_VENDOR_ID                                             |
    -- | Description      : This procedure  is used to get                 |
    -- |                    vendor id from EBS                             |
    -- |                                                                   |
    -- | Parameters : p_vendor_num                                         |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_vendor_id                                             |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT aps.vendor_id
          INTO x_vendor_id
          FROM ap_suppliers aps
         WHERE UPPER (segment1) = UPPER (p_vendor_num);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error (
                  'PO',
                  gn_org_id,
                  'XXD Open Purchase Orders Conversion Program',
                  --      SQLCODE,
                  'Exception to GET_VENDOR_ID Procedure' || SQLERRM,
                  DBMS_UTILITY.format_error_backtrace,
                  --   DBMS_UTILITY.format_call_stack,
                  --    SYSDATE,
                  gn_user_id,
                  gn_conc_request_id,
                  'GET_VENDOR_ID',
                  p_vendor_num);
               write_log ('Exception to GET_VENDOR_ID Procedure' || SQLERRM); */
            NULL;
    END GET_VENDOR_ID;

    PROCEDURE GET_VENDORS_ID (p_vendor_name   IN            VARCHAR2,
                              x_vendor_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_VENDORS_ID                                            |
    -- | Description      : This procedure  is used to get                 |
    -- |                    vender id from EBS                             |
    -- |                                                                   |
    -- | Parameters : p_vendor_name                                        |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_vendor_id                                             |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT aps.vendor_id
          INTO x_vendor_id
          FROM ap_suppliers aps
         WHERE UPPER (vendor_name) = UPPER (p_vendor_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error (
                  'PO',
                  gn_org_id,
                  'XXD Open Purchase Orders Conversion Program',
                  --      SQLCODE,
                  'Exception to GET_VENDORS_ID Procedure' || SQLERRM,
                  DBMS_UTILITY.format_error_backtrace,
                  --   DBMS_UTILITY.format_call_stack,
                  --    SYSDATE,
                  gn_user_id,
                  gn_conc_request_id,
                  'GET_VENDORS_ID',
                  p_vendor_name);
               write_log ('Exception to GET_VENDORS_ID Procedure' || SQLERRM); */
            NULL;
    END GET_VENDORS_ID;

    PROCEDURE GET_VENDOR_SITE_ID (p_vendor_code IN VARCHAR2, p_org_id IN VARCHAR2, p_vendor_id IN NUMBER
                                  , x_vendor_site_id OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_VENDOR_SITE_ID                                        |
    -- | Description      : This procedure is used to get                  |
    -- |                    vender id from EBS                             |
    -- |                                                                   |
    -- | Parameters : p_vendor_code,p_org_id                               |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_vendor_site_id                                        |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT apss.vendor_site_id
          INTO x_vendor_site_id
          FROM ap_supplier_sites_all apss
         WHERE     UPPER (apss.vendor_site_code) = UPPER (p_vendor_code)
               AND apss.vendor_id = p_vendor_id
               AND apss.org_id = p_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*     xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --      SQLCODE,
                    'Exception to GET_VENDOR_SITE_ID Procedure' || SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'GET_VENDOR_SITE_ID',
                    p_vendor_code);
                 write_log ('Exception to GET_VENDOR_SITE_ID Procedure' || SQLERRM); */
            NULL;
    END GET_VENDOR_SITE_ID;

    FUNCTION CHECK_FREIGHT_CARRIER (p_freight_carr IN VARCHAR2)
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name  : CHECK_FREIGHT_CARRIER                                     |
    -- | Description      : This function  is used to check                |
    -- |                    if freight carrier exist in EBS                |
    -- |                                                                   |
    -- | Parameters : p_freight_carr                                       |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        lc_status   VARCHAR2 (1);
    BEGIN
        SELECT 'X'
          INTO lc_status
          FROM SYS.DUAL
         WHERE EXISTS
                   (SELECT DISTINCT freight_code
                      FROM org_freight_tl
                     WHERE UPPER (freight_code) = UPPER (p_freight_carr));

        RETURN lc_status;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'Y';
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to CHECK_FREIGHT_CARRIER Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'CHECK_FREIGHT_CARRIER',
                 p_freight_carr);
              write_log (
                 'Exception to CHECK_FREIGHT_CARRIER Procedure' || SQLERRM); */
            RETURN NULL;
    END CHECK_FREIGHT_CARRIER;

    PROCEDURE GET_FREIGHT_CARRIER (p_freight_name   IN            VARCHAR2,
                                   x_freight_code      OUT NOCOPY VARCHAR2)
    -- +===================================================================+
    -- | Name  : GET_FREIGHT_CARRIER                                       |
    -- | Description      : This procedure  is used to get                 |
    -- |                    freight carrier code                           |
    -- |                                                                   |
    -- | Parameters : p_freight_name                                       |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_freight_code                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT DISTINCT freight_code
          INTO x_freight_code
          FROM org_freight_tl
         WHERE UPPER (freight_code_tl) = UPPER (p_freight_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*     xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --      SQLCODE,
                    'Exception to GET_FREIGHT_CARRIER Procedure' || SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'GET_FREIGHT_CARRIER',
                    p_freight_name);
                 write_log ('Exception to GET_FREIGHT_CARRIER Procedure' || SQLERRM); */
            NULL;
    END GET_FREIGHT_CARRIER;

    FUNCTION CHECK_FREIGHT_TERMS (p_freight_terms IN VARCHAR2)
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name  : CHECK_FREIGHT_TERMS                                       |
    -- | Description      : This function  is used to check if             |
    -- |                    freight terms is valid                         |
    -- |                                                                   |
    -- | Parameters : p_freight_terms                                      |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        lc_status   VARCHAR2 (1);
    BEGIN
        SELECT 'X'
          INTO lc_status
          FROM SYS.DUAL
         WHERE EXISTS
                   (SELECT lookup_code
                      FROM po_lookup_codes
                     WHERE     lookup_type = 'FREIGHT TERMS'
                           AND UPPER (lookup_code) = UPPER (p_freight_terms));

        RETURN lc_status;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'Y';
        WHEN OTHERS
        THEN
            /*     xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --      SQLCODE,
                    'Exception to CHECK_FREIGHT_TERMS Procedure' || SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'CHECK_FREIGHT_TERMS',
                    p_freight_terms);
                 write_log ('Exception to CHECK_FREIGHT_TERMS Procedure' || SQLERRM); */
            NULL;
    END CHECK_FREIGHT_TERMS;

    PROCEDURE GET_VENDOR_CONTACT_ID (p_vendor_contact_name IN VARCHAR2, p_vendor_site_id IN NUMBER, p_vendor_id IN NUMBER
                                     , x_vendor_contact_id OUT NOCOPY NUMBER)
    IS
        -- +===================================================================+
        -- | Name  : GET_VENDOR_CONTACT_ID                                     |
        -- | Description      : This procedure  is used to get                 |
        -- |                    fob code                                       |
        -- |                                                                   |
        -- | Parameters : p_vendor_contact_name,p_vendor_site_id               |
        -- |                                                                   |
        -- |                                                                   |
        -- | Returns :  x_vendor_contact_id                                    |
        -- |                                                                   |
        -- +===================================================================+
        ln_vendor_conatct_id   NUMBER;
    BEGIN
        SELECT MAX (vendor_contact_id)
          INTO x_vendor_contact_id
          FROM ap_suppliers ap, ap_supplier_sites_all assa, po_supplier_contacts_val_v psc
         WHERE     ap.vendor_id = assa.vendor_id
               AND psc.vendor_site_id = assa.vendor_site_id
               AND ap.vendor_id = p_vendor_id
               AND psc.vendor_site_id = p_vendor_site_id
               AND UPPER (full_name) = UPPER (p_vendor_contact_name);

        IF x_vendor_contact_id IS NULL
        THEN
            BEGIN
                SELECT MAX (vendor_contact_id)
                  INTO x_vendor_contact_id
                  FROM ap_suppliers ap, ap_supplier_sites_all assa, po_supplier_contacts_val_v psc
                 WHERE     ap.vendor_id = assa.vendor_id
                       AND psc.vendor_site_id = assa.vendor_site_id
                       AND ap.vendor_id = p_vendor_id
                       AND psc.vendor_site_id = p_vendor_site_id
                       AND UPPER (contact) = UPPER (p_vendor_contact_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                           --      SQLCODE,
                           'Exception to GET_VENDOR_CONTACT_ID Procedure'
                        || SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'GET_VENDOR_CONTACT_ID',
                        p_vendor_contact_name);
                    write_log (
                           'Exception to GET_VENDOR_CONTACT_ID Procedure'
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            /*    xxd_common_utils.record_error (
                   'PO',
                   gn_org_id,
                   'XXD Open Purchase Orders Conversion Program',
                   --      SQLCODE,
                   'Exception to GET_VENDOR_CONTACT_ID Procedure' || SQLERRM,
                   DBMS_UTILITY.format_error_backtrace,
                   --   DBMS_UTILITY.format_call_stack,
                   --    SYSDATE,
                   gn_user_id,
                   gn_conc_request_id,
                   'GET_VENDOR_CONTACT_ID',
                   p_vendor_contact_name);
                write_log (
                   'Exception to GET_VENDOR_CONTACT_ID Procedure' || SQLERRM); */
            NULL;
    END GET_VENDOR_CONTACT_ID;

    PROCEDURE GET_USER_ID (p_user_name   IN            VARCHAR2,
                           x_user_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_USER_ID                                               |
    -- | Description      : This procedure  is used to get                 |
    -- |                    fob code                                       |
    -- |                                                                   |
    -- | Parameters : p_user_name                                          |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_user_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT user_id
          INTO x_user_id
          FROM fnd_user
         WHERE UPPER (user_name) = UPPER (p_user_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*    xxd_common_utils.record_error (
                   'PO',
                   gn_org_id,
                   'XXD Open Purchase Orders Conversion Program',
                   --      SQLCODE,
                   'Exception to GET_USER_ID Procedure' || SQLERRM,
                   DBMS_UTILITY.format_error_backtrace,
                   --   DBMS_UTILITY.format_call_stack,
                   --    SYSDATE,
                   gn_user_id,
                   gn_conc_request_id,
                   'GET_USER_ID',
                   p_user_name);
                write_log ('Exception to GET_USER_ID Procedure' || SQLERRM); */
            NULL;
    END GET_USER_ID;

    FUNCTION CHECK_UOM (p_uom_code IN VARCHAR2)
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name  : CHECK_UOM                                                 |
    -- | Description      : This function  is used to check if             |
    -- |                    UOM Code is valid                              |
    -- |                                                                   |
    -- | Parameters : p_uom_code                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        lc_status   VARCHAR2 (1);
    BEGIN
        SELECT 'X'
          INTO lc_status
          FROM SYS.DUAL
         WHERE EXISTS
                   (SELECT muom.unit_of_measure
                      FROM mtl_units_of_measure_tl muom
                     WHERE     UPPER (muom.unit_of_measure_tl) =
                               UPPER (p_uom_code)
                           AND NVL (disable_date, SYSDATE) >= SYSDATE);

        RETURN lc_status;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'Y';
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to CHECK_UOM Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'CHECK_UOM',
                 p_uom_code);
              write_log ('Exception to CHECK_UOM Procedure' || SQLERRM); */
            NULL;
    END CHECK_UOM;

    FUNCTION CHECK_FOB (p_fob_code IN VARCHAR2)
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name  : CHECK_FOB                                                 |
    -- | Description      : This function  is used to check if             |
    -- |                    fob code is valid                              |
    -- |                                                                   |
    -- | Parameters : p_fob_code                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        lc_status   VARCHAR2 (1);
    BEGIN
        SELECT 'X'
          INTO lc_status
          FROM SYS.DUAL
         WHERE EXISTS
                   (SELECT lookup_code
                      FROM po_lookup_codes
                     WHERE     lookup_type = 'FOB'
                           AND UPPER (displayed_field) = UPPER (p_fob_code));

        RETURN lc_status;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'Y';
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to CHECK_FOB Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'CHECK_FOB',
                 p_fob_code);
              write_log ('Exception to CHECK_FOB Procedure' || SQLERRM); */
            NULL;
    END CHECK_FOB;

    PROCEDURE GET_FOB_CODE (p_fob_name IN VARCHAR2 --  ,p_source_table             IN         VARCHAR2
                                                  , x_fob_code OUT VARCHAR2)
    -- +===================================================================+
    -- | Name  : GET_FOB_CODE                                              |
    -- | Description      : This procedure  is used to get                 |
    -- |                    fob code                                       |
    -- |                                                                   |
    -- | Parameters : p_fob_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_fob_code                                             |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT lookup_code
          INTO x_fob_code
          FROM po_lookup_codes
         WHERE     lookup_type = 'FOB'
               AND UPPER (displayed_field) = UPPER (p_fob_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error (
                  'PO',
                  gn_org_id,
                  'XXD Open Purchase Orders Conversion Program',
                  --      SQLCODE,
                  'Exception to GET_FOB_CODE Procedure' || SQLERRM,
                  DBMS_UTILITY.format_error_backtrace,
                  --   DBMS_UTILITY.format_call_stack,
                  --    SYSDATE,
                  gn_user_id,
                  gn_conc_request_id,
                  'GET_FOB_CODE',
                  p_fob_name);
               write_log ('Exception to GET_FOB_CODE Procedure' || SQLERRM); */
            NULL;
    END GET_FOB_CODE;

    PROCEDURE GET_SHIP_TO_ORG_ID (p_org_code   IN            VARCHAR2,
                                  x_org_id        OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_SHIP_TO_ORG_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    ship to org code                               |
    -- |                                                                   |
    -- | Parameters : p_org_code                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_org_id                                               |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    BEGIN
        write_log ('Ship to Organization code p_org_code => ' || p_org_code);
        px_meaning   := p_org_code;
        apps.XXD_COMMON_UTILS.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        write_log ('Ship to Organization code => ' || x_attribute1);

        SELECT mp.organization_id
          INTO x_org_id
          FROM mtl_parameters mp
         WHERE UPPER (mp.organization_code) = UPPER (x_attribute1);

        write_log ('New Ship to Organization id => ' || x_org_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*    xxd_common_utils.record_error (
                   'PO',
                   gn_org_id,
                   'XXD Open Purchase Orders Conversion Program',
                   --      SQLCODE,
                   'Exception to GET_SHIP_TO_ORG_ID Procedure' || SQLERRM,
                   DBMS_UTILITY.format_error_backtrace,
                   --   DBMS_UTILITY.format_call_stack,
                   --    SYSDATE,
                   gn_user_id,
                   gn_conc_request_id,
                   'GET_SHIP_TO_ORG_ID',
                   p_org_code);
                write_log ('Exception to GET_SHIP_TO_ORG_ID Procedure' || SQLERRM); */
            NULL;
    END GET_SHIP_TO_ORG_ID;

    PROCEDURE GET_ITEM_ID (p_item         IN            VARCHAR2,
                           p_inv_org_id   IN            NUMBER,
                           x_item_id         OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_ITEM_ID                                               |
    -- | Description      : This procedure  is used to get                 |
    -- |                    item id                                        |
    -- |                                                                   |
    -- | Parameters : p_item, p_inv_org_id                                 |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_item_id                                              |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT msib.INVENTORY_ITEM_ID
          INTO x_item_id
          FROM mtl_system_items_kfv msib
         WHERE     UPPER (msib.CONCATENATED_SEGMENTS) = UPPER (p_item)
               AND msib.organization_id = p_inv_org_id;
    -- AND msib.organization_id = fnd_profile.VALUE ('SO_ORGANIZATION_ID');

    EXCEPTION
        WHEN OTHERS
        THEN
            /*   xxd_common_utils.record_error (
                  'PO',
                  gn_org_id,
                  'XXD Open Purchase Orders Conversion Program',
                  --      SQLCODE,
                  'Exception to GET_ITEM_ID Procedure' || SQLERRM,
                  DBMS_UTILITY.format_error_backtrace,
                  --   DBMS_UTILITY.format_call_stack,
                  --    SYSDATE,
                  gn_user_id,
                  gn_conc_request_id,
                  'GET_ITEM_ID',
                  p_item);
               write_log ('Exception to GET_ITEM_ID Procedure' || SQLERRM); */
            NULL;
    END GET_ITEM_ID;

    PROCEDURE GET_UOM (p_uom_code   IN            VARCHAR2,
                       x_uom_code      OUT NOCOPY VARCHAR2)
    -- +===================================================================+
    -- | Name  : GET_UOM                                                   |
    -- | Description      : This procedure  is used to get                 |
    -- |                    UOM code                                       |
    -- |                                                                   |
    -- | Parameters : p_uom_code                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_uom_code                                             |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        --      SELECT muom.unit_of_measure
        --        INTO x_uom_code
        --        FROM mtl_units_of_measure_tl muom
        --       WHERE upper(muom.uom_code) = upper(p_uom_code)
        --         AND NVL (disable_date, SYSDATE) >= SYSDATE
        --         AND muom.LANGUAGE = USERENV ('LANG');

        SELECT muom.uom_code
          INTO x_uom_code
          FROM mtl_units_of_measure_tl muom
         WHERE     1 = 1
               --Modified for 08-MAY-2015
               --AND UPPER (muom.unit_of_measure) = UPPER ('Pair')
               AND UPPER (muom.unit_of_measure) = UPPER (p_uom_code)
               --Modified for 08-MAY-2015
               AND NVL (disable_date, SYSDATE) >= SYSDATE
               AND muom.LANGUAGE = USERENV ('LANG');
    EXCEPTION
        WHEN OTHERS
        THEN
            /*     xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --      SQLCODE,
                    'Exception to GET_UOM Procedure' || SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'GET_UOM',
                    p_uom_code);
                 write_log ('Exception to GET_UOM Procedure' || SQLERRM); */
            NULL;
    END GET_UOM;

    PROCEDURE GET_CATEGORY_ID (p_item_id       IN            NUMBER,
                               p_inv_org       IN            NUMBER,
                               x_category_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_CATEGORY_ID                                           |
    -- | Description      : This procedure  is used to get                 |
    -- |                    category id from category                      |
    -- |                                                                   |
    -- | Parameters : p_item_id,p_inv_org                                  |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_category_id                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT category_id
          INTO x_category_id
          FROM mtl_item_categories pa, mtl_category_sets_tl mt
         WHERE     inventory_item_id = p_item_id
               AND organization_id = p_inv_org
               AND pa.category_set_id = mt.category_set_id
               --AND category_set_name = 'Purchasing'
               AND category_set_name = 'PO Item Category'
               AND mt.language = 'US';
    EXCEPTION
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to GET_CATEGORY_ID Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'GET_CATEGORY_ID',
                 'Item ' || p_item_id || ' and Inv Org ' || p_inv_org);
              write_log ('Exception to GET_CATEGORY_ID Procedure' || SQLERRM); */
            NULL;
    END GET_CATEGORY_ID;

    PROCEDURE GET_LINE_TYPE_ID (p_line_type      IN            VARCHAR2,
                                x_line_type_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_LINE_TYPE_ID                                          |
    -- | Description      : This procedure  is used to get                 |
    -- |                    line type id from line type                    |
    -- |                                                                   |
    -- | Parameters : p_line_type                                          |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_line_type_id                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT line_type_id
          INTO x_line_type_id
          FROM po_line_types_tl
         WHERE UPPER (line_type) = UPPER (p_line_type);
    EXCEPTION
        WHEN OTHERS
        THEN
            /*     xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --      SQLCODE,
                    'Exception to GET_LINE_TYPE_ID Procedure' || SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'GET_LINE_TYPE_ID',
                    p_line_type);
                 write_log ('Exception to GET_LINE_TYPE_ID Procedure' || SQLERRM); */
            NULL;
    END GET_LINE_TYPE_ID;

    PROCEDURE GET_UNIT_PRICE_ID (p_item_id         IN            NUMBER,
                                 p_inv_org         IN            NUMBER,
                                 x_list_price_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_UNIT_PRICE_ID                                         |
    -- | Description      : This procedure  is used to get                 |
    -- |                    list price id from line id and org             |
    -- |                                                                   |
    -- | Parameters : p_item_id                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_list_price_id                                        |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT list_price_per_unit
          INTO x_list_price_id
          FROM mtl_system_items_b c
         WHERE inventory_item_id = p_item_id AND organization_id = p_inv_org;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to GET_UNIT_PRICE_ID Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'GET_UNIT_PRICE_ID',
                 'Item ' || p_item_id || ' and Inv Org ' || p_inv_org);
              write_log ('Exception to GET_UNIT_PRICE_ID Procedure' || SQLERRM); */
            NULL;
    END GET_UNIT_PRICE_ID;

    PROCEDURE GET_DIR_FROM_ITEM (p_item_id IN NUMBER, p_inv_org IN NUMBER, x_dys_early_recit_allow OUT NUMBER, x_dys_late_recit_allow OUT NUMBER, x_invoice_close_tolrance OUT NUMBER, x_receive_close_tolrance OUT NUMBER
                                 , x_receiving_routing_id OUT NUMBER)
    -- +===================================================================+
    -- | Name  : GET_DIR_FROM_ITEM                                         |
    -- | Description      : This procedure  is used to get                 |
    -- |                    days_early_receipt, days_late_receipt          |
    -- |                    invoice_close_tolerance, receive_close         |
    -- |                    receiving_routing_id                           |
    -- |                                                                   |
    -- | Parameters : p_segment                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_acc_acct_id                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT days_early_receipt_allowed, days_late_receipt_allowed, invoice_close_tolerance,
               receive_close_tolerance, receiving_routing_id
          INTO x_dys_early_recit_allow, x_dys_late_recit_allow, x_invoice_close_tolrance, x_receive_close_tolrance,
                                      x_receiving_routing_id
          FROM mtl_system_items_fvl
         WHERE inventory_item_id = p_item_id AND organization_id = p_inv_org;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            /*  xxd_common_utils.record_error (
                 'PO',
                 gn_org_id,
                 'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception to GET_DIR_FROM_ITEM Procedure' || SQLERRM,
                 DBMS_UTILITY.format_error_backtrace,
                 --   DBMS_UTILITY.format_call_stack,
                 --    SYSDATE,
                 gn_user_id,
                 gn_conc_request_id,
                 'GET_DIR_FROM_ITEM',
                 'Item ' || p_item_id || ' and Inv Org ' || p_inv_org);
              write_log ('Exception to GET_DIR_FROM_ITEM Procedure' || SQLERRM); */
            NULL;
    END GET_DIR_FROM_ITEM;

    PROCEDURE GET_CHARGE_ACCT_ID (p_segment         IN            VARCHAR2,
                                  x_charg_acct_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_CHARGE_ACCT_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    charge account id from segment                 |
    -- |                                                                   |
    -- | Parameters : p_segment                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_charg_acct_id                                        |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_charg_acct_id
          FROM gl_code_combinations_kfv
         WHERE concatenated_segments = p_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_CHARGE_ACCT_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_CHARGE_ACCT_ID',
                p_segment);
            write_log (
                'Exception to GET_CHARGE_ACCT_ID Procedure' || SQLERRM);
    END GET_CHARGE_ACCT_ID;

    PROCEDURE GET_ACCURL_ACCT_ID (p_segment       IN            VARCHAR2,
                                  x_acc_acct_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_CHARGE_ACCT_ID                                        |
    -- | Description      : This procedure  is used to get                 |
    -- |                    accural account id from segment                |
    -- |                                                                   |
    -- | Parameters : p_segment                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_acc_acct_id                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_acc_acct_id
          FROM gl_code_combinations_kfv
         WHERE concatenated_segments = p_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_ACCURL_ACCT_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ACCURL_ACCT_ID',
                p_segment);
            write_log (
                'Exception to GET_ACCURL_ACCT_ID Procedure' || SQLERRM);
    END GET_ACCURL_ACCT_ID;

    PROCEDURE GET_VARIANCE_ACCT_ID (p_segment       IN            VARCHAR2,
                                    x_var_acct_id      OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_VARIANCE_ACCT_ID                                      |
    -- | Description      : This procedure  is used to get                 |
    -- |                    variance account id from segment               |
    -- |                                                                   |
    -- | Parameters : p_segment                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_var_acct_id                                          |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_var_acct_id
          FROM gl_code_combinations_kfv
         WHERE concatenated_segments = p_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_VARIANCE_ACCT_ID Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_VARIANCE_ACCT_ID',
                p_segment);
            write_log (
                'Exception to GET_VARIANCE_ACCT_ID Procedure' || SQLERRM);
    END GET_VARIANCE_ACCT_ID;

    PROCEDURE GET_LINE_COUNT (p_doc_num IN VARCHAR2, x_cnt OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_LINE_COUNT                                            |
    -- | Description      : This procedure  is used to get                 |
    -- |                    line count                                     |
    -- |                                                                   |
    -- | Parameters : p_doc_num                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_cnt                                                  |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT COUNT (*)
          INTO x_cnt
          FROM XXD_PO_LINES_STG_T
         WHERE interface_header_id = p_doc_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_LINE_COUNT Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_LINE_COUNT',
                p_doc_num);
            write_log ('Exception to GET_LINE_COUNT Procedure' || SQLERRM);
    END GET_LINE_COUNT;

    PROCEDURE GET_DISTIR_COUNT (p_doc_num   IN            VARCHAR2,
                                x_cnt          OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_LINE_COUNT                                            |
    -- | Description      : This procedure  is used to get                 |
    -- |                    distributions count                            |
    -- |                                                                   |
    -- | Parameters : p_doc_num                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_cnt                                                  |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT COUNT (*)
          INTO x_cnt
          FROM XXD_PO_DISTRIBUTIONS_STG_T
         WHERE interface_header_id = p_doc_num;
    --and status='NEW';

    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_DISTIR_COUNT Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_DISTIR_COUNT',
                p_doc_num);
            write_log ('Exception to GET_DISTIR_COUNT Procedure' || SQLERRM);
    END GET_DISTIR_COUNT;

    PROCEDURE GET_LINE_LOC_COUNT (p_doc_num   IN            VARCHAR2,
                                  x_cnt          OUT NOCOPY NUMBER)
    -- +===================================================================+
    -- | Name  : GET_LINE_COUNT                                            |
    -- | Description      : This procedure  is used to get                 |
    -- |                    distributions count                            |
    -- |                                                                   |
    -- | Parameters : p_doc_num                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_cnt                                                  |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT COUNT (*)
          INTO x_cnt
          FROM XXD_PO_LINE_LOCATIONS_STG_T
         WHERE interface_header_id = p_doc_num;
    --and status='NEW';

    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_LINE_LOC_COUNT Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_LINE_LOC_COUNT',
                p_doc_num);
            write_log (
                'Exception to GET_LINE_LOC_COUNT Procedure' || SQLERRM);
    END GET_LINE_LOC_COUNT;

    PROCEDURE GET_INV_EXP_FLAG (p_item_id   IN     NUMBER,
                                p_inv_org   IN     NUMBER,
                                x_flag         OUT VARCHAR2)
    -- +===================================================================+
    -- | Name  : GET_INV_EXP_FLAG                                          |
    -- | Description      : This procedure is used to check if line item is|
    -- |                    inventory or expense item                      |
    -- |                                                                   |
    -- | Parameters : p_item_id, p_inv_org                                 |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_flag                                                 |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT inventory_item_flag
          INTO x_flag
          FROM mtl_system_items_b
         WHERE inventory_item_id = p_item_id AND organization_id = p_inv_org;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Exception to GET_INV_EXP_FLAG Procedure' || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_INV_EXP_FLAG',
                'Item ' || p_item_id || ' and Inv Org ' || p_inv_org);
            write_log ('Exception to GET_INV_EXP_FLAG Procedure' || SQLERRM);
    END GET_INV_EXP_FLAG;

    PROCEDURE GET_CHARGE_ACCUR_VAR_ACCNT (p_inv_org IN NUMBER, x_material_accnt OUT NUMBER, x_accrual_accnt OUT NUMBER
                                          , x_var_accnt OUT NUMBER)
    -- +===================================================================+
    -- | Name  : GET_CHARGE_ACCUR_VAR_ACCNT                                |
    -- | Description      : This procedure is used to get                  |
    -- |                    charge, accural and variance account id for the|
    -- |                    inventory org                                  |
    -- |                                                                   |
    -- | Parameters : p_inv_org                                            |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :  x_material_accnt, x_accrual_accnt, x_var_accnt         |
    -- |                                                                   |
    -- +===================================================================+
    IS
    BEGIN
        SELECT material_account, ap_accrual_account, purchase_price_var_account
          INTO x_material_accnt, x_accrual_accnt, x_var_accnt
          FROM mtl_parameters_view mp
         WHERE organization_id = p_inv_org;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                   --      SQLCODE,
                   'Exception to GET_CHARGE_ACCUR_VAR_ACCNT Procedure'
                || SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_CHARGE_ACCUR_VAR_ACCNT',
                'Inv Org ' || p_inv_org);
            write_log (
                   'Exception to GET_CHARGE_ACCUR_VAR_ACCNT Procedure'
                || SQLERRM);
    END GET_CHARGE_ACCUR_VAR_ACCNT;

    PROCEDURE GET_ORCL_ITEM_FRM_LEGACY_ITEM (p_item_number IN VARCHAR2, p_org_id IN NUMBER, x_item_id OUT NUMBER
                                             , x_status OUT VARCHAR2)
    -- +====================================================================================================+
    -- |                                                                                                    |
    -- | Name           :   GET_ORCL_ITEM_FRM_LEGACY_ITEM                                                   |
    -- |                                                                                                    |
    -- | Description    :   GET_ORCL_ITEM_FRM_LEGACY_ITEM procedure.                                        |
    -- |                    This procedure is used to derive the inventory item id                          |
    -- |                                                                                                    |
    -- | Parameters     :   p_item_number, p_loc_id                                                         |
    -- |                                                                                                    |
    -- | Returns        :   x_item_id, x_status                                                             |
    -- |                                                                                                    |
    -- +====================================================================================================+

    IS
    BEGIN
        x_status   := 'Y';

        SELECT inventory_item_id
          INTO x_item_id
          FROM mtl_system_items_b
         WHERE     UPPER (segment1) = UPPER (p_item_number)
               AND organization_id = p_org_id;
    --AND outside_operation_flag = 'Y';

    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_item_id   := NULL;
            x_status    := 'N';
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --      SQLCODE,
                'Item Does not exist',
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                p_item_number,
                'Item Does not exist');
            write_log (
                   'Exception to GET_ORCL_ITEM_FRM_LEGACY_ITEM Procedure'
                || SQLERRM);
    /*    WHEN TOO_MANY_ROWS
        THEN
           x_item_id := -1;
           x_status := 'N';
           xxd_common_utils.record_error (
              'PO',
              gn_org_id,
              'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception Of Two many Rows GET_ORCL_ITEM_FRM_LEGACY_ITEM Procedure'
              || SQLERRM,
              DBMS_UTILITY.format_error_backtrace,
              --   DBMS_UTILITY.format_call_stack,
              --    SYSDATE,
              gn_user_id,
              gn_conc_request_id,
              'GET_CHARGE_ACCUR_VAR_ACCNT',
              'Inv item ' || p_item_number);
           write_log (
              'Exception to GET_ORCL_ITEM_FRM_LEGACY_ITEM Procedure' || SQLERRM);
        WHEN OTHERS
        THEN
           x_item_id := -1;
           x_status := 'U';

           xxd_common_utils.record_error (
              'PO',
              gn_org_id,
              'XXD Open Purchase Orders Conversion Program',
                 --      SQLCODE,
                 'Exception Of When Others GET_ORCL_ITEM_FRM_LEGACY_ITEM Procedure'
              || SQLERRM,
              DBMS_UTILITY.format_error_backtrace,
              --   DBMS_UTILITY.format_call_stack,
              --    SYSDATE,
              gn_user_id,
              gn_conc_request_id,
              'GET_CHARGE_ACCUR_VAR_ACCNT',
              'Inv item ' || p_item_number);
           write_log (
              'Exception to GET_ORCL_ITEM_FRM_LEGACY_ITEM Procedure' || SQLERRM); */
    END GET_ORCL_ITEM_FRM_LEGACY_ITEM;

    PROCEDURE VALIDATE_OPEN_PO_DISTRIBUTIONS (
        p_po_header_id     IN     NUMBER,
        p_po_line_id       IN     NUMBER,
        p_item_id          IN     NUMBER,
        p_ship_to_org_id   IN     NUMBER,
        x_return_flag         OUT VARCHAR2)
    AS
        -- +===================================================================+
        -- | Name  : VALIDATE_OPEN_PO_DISTRIBUTIONS                            |
        -- | Description      :  Procedure to validate the purchase order lines|
        -- |                    staging data                                   |
        -- |                                                                   |
        -- | Parameters :   p_po_header_id ,p_po_line_id                       |
        -- |                                                                   |
        -- | Returns :   x_error_tbl ,  x_return_flag                          |
        -- |                                                                   |
        -- +===================================================================+

        --Cursor for po distributions staging
        CURSOR cur_po_dist (p_po_header_id NUMBER, p_po_line_id NUMBER)
        IS
            SELECT xdes.*
              FROM XXD_PO_DISTRIBUTIONS_STG_T xdes
             WHERE     xdes.po_header_id = p_po_header_id
                   AND xdes.po_line_id = p_po_line_id;

        CURSOR cur_po_location_chk (p_location_code VARCHAR2)
        IS
            SELECT location_code
              FROM hr_locations
             WHERE location_code = p_location_code;

        CURSOR cur_person_chk (p_full_name VARCHAR2)
        IS
            SELECT person_id
              FROM per_all_people_f
             WHERE     full_name = p_full_name
                   AND SYSDATE BETWEEN effective_start_date
                                   AND effective_end_date;

        CURSOR cur_get_new_inv_org (p_old_org_code VARCHAR2)
        IS
            SELECT mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND meaning = p_old_org_code
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.attribute1;

        CURSOR cur_get_new_sob (p_sob VARCHAR2)
        IS
            SELECT gl.ledger_id
              FROM fnd_lookup_values flv, gl_ledgers gl
             WHERE     lookup_type = 'XXD_1206_LEDGER_MAPPING'
                   AND meaning = p_sob
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND gl.name = flv.attribute1;

        /*    CURSOR cur_get_new_ccid(p_code_combination VARCHAR2)
            IS
               SELECT gl.code_combination_id
               FROM xxd_conv.xxd_gl_coa_mapping_t a
                   ,gl_code_combinations_kfv      gl
               WHERE  a.old_company||'.'||a.old_cost_center||'.'||a.old_natural_account||'.'
                      ||a.old_product                                                             = p_code_combination
               AND    a.new_company||'.'|| a.new_brand||'.'|| a.new_geo||'.'||a.new_channel|| '.'
                   || a.new_cost_center|| '.'|| a.new_natural_account|| '.'|| a.new_intercompany  = gl.concatenated_segments
               AND NVL (a.enabled_flag, 'Y') = 'Y'
               AND gl.enabled_flag           = 'Y';
       */
        ln_accur_accnt_id          NUMBER;
        ln_budget_acct_id          NUMBER;
        ln_var_accnt_id            NUMBER;
        lc_master_flag             VARCHAR2 (20);
        lt_po_dist_data            gtab_po_dist;
        lc_location_code           VARCHAR2 (60);
        ln_person_id               NUMBER;
        lc_new_inv_org_id          NUMBER;
        lc_new_sob_id              NUMBER;
        ln_dest_charge_acct_id     NUMBER;
        ln_dest_variance_acct_id   NUMBER;
    BEGIN
        ln_accur_accnt_id          := NULL;
        ln_budget_acct_id          := NULL;
        ln_var_accnt_id            := NULL;
        lc_master_flag             := NULL;

        lc_location_code           := NULL;
        ln_person_id               := NULL;
        lc_new_inv_org_id          := NULL;
        lc_new_sob_id              := NULL;
        ln_dest_charge_acct_id     := NULL;
        ln_dest_variance_acct_id   := NULL;

        lt_po_dist_data.delete;

        --open po distribution cursor
        OPEN cur_po_dist (p_po_header_id, p_po_line_id);

        FETCH cur_po_dist BULK COLLECT INTO lt_po_dist_data;

        CLOSE cur_po_dist;

        x_return_flag              := gc_validate_status;
        lc_master_flag             := gc_validate_status;

        IF lt_po_dist_data.COUNT > 0
        THEN
            --start the loop for po distribution
            FOR po_distr_stg_indx IN lt_po_dist_data.FIRST ..
                                     lt_po_dist_data.LAST
            LOOP
                IF lt_po_dist_data (po_distr_stg_indx).deliver_to_location
                       IS NOT NULL
                THEN
                    OPEN cur_po_location_chk (
                        lt_po_dist_data (po_distr_stg_indx).deliver_to_location);

                    FETCH cur_po_location_chk INTO lc_location_code;

                    CLOSE cur_po_location_chk;

                    IF lc_location_code IS NULL
                    THEN
                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               'Location code doesnt exists at distribution  => '
                            || lt_po_dist_data (po_distr_stg_indx).deliver_to_location,
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_conc_request_id,
                            'LOCATION CODE IS NOT EXISTS',
                            lt_po_dist_data (po_distr_stg_indx).po_line_id,
                            lt_po_dist_data (po_distr_stg_indx).DISTRIBUTION_NUM,
                            'LOCATION_CODE_NOT_EXISTS');

                        lc_master_flag   := gc_error_status;
                    END IF;                 --IF lc_location_code IS NULL THEN
                END IF;

                IF lt_po_dist_data (po_distr_stg_indx).deliver_to_person_full_name
                       IS NOT NULL
                THEN
                    OPEN cur_person_chk (
                        lt_po_dist_data (po_distr_stg_indx).deliver_to_person_full_name);

                    FETCH cur_person_chk INTO ln_person_id;

                    CLOSE cur_person_chk;

                    IF ln_person_id IS NULL
                    THEN
                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               'Person is not defined at distribution  => '
                            || lt_po_dist_data (po_distr_stg_indx).deliver_to_person_full_name,
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_conc_request_id,
                            'PERSON IS NOT DEFINED',
                            lt_po_dist_data (po_distr_stg_indx).po_line_id,
                            lt_po_dist_data (po_distr_stg_indx).DISTRIBUTION_NUM,
                            'PERSON_NOT_EXISTS');
                        lc_master_flag   := gc_error_status;
                    END IF;                     --IF ln_person_id IS NULL THEN
                END IF;

                IF lt_po_dist_data (po_distr_stg_indx).destination_organization
                       IS NOT NULL
                THEN
                    OPEN cur_get_new_inv_org (
                        lt_po_dist_data (po_distr_stg_indx).destination_organization);

                    FETCH cur_get_new_inv_org INTO lc_new_inv_org_id;

                    CLOSE cur_get_new_inv_org;

                    IF lc_new_inv_org_id IS NULL
                    THEN
                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               'New Inv Org mapping is missing at distribution for OU => '
                            || lt_po_dist_data (po_distr_stg_indx).destination_organization,
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_conc_request_id,
                            'New INV ORG IS MISSING',
                            lt_po_dist_data (po_distr_stg_indx).po_line_id,
                            lt_po_dist_data (po_distr_stg_indx).DISTRIBUTION_NUM,
                            'New INV ORG IS MISSING');
                        lc_master_flag   := gc_error_status;
                    END IF;                --IF lc_new_inv_org_id IS NULL THEN
                END IF;

                IF lt_po_dist_data (po_distr_stg_indx).set_of_books
                       IS NOT NULL
                THEN
                    OPEN cur_get_new_sob (
                        lt_po_dist_data (po_distr_stg_indx).set_of_books);

                    FETCH cur_get_new_sob INTO lc_new_sob_id;

                    CLOSE cur_get_new_sob;

                    IF lc_new_sob_id IS NULL
                    THEN
                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               'New set of book mapping is missing at distribution for ledger name => '
                            || lt_po_dist_data (po_distr_stg_indx).set_of_books,
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_conc_request_id,
                            'NEW SET OF BOOK IS MISSING',
                            lt_po_dist_data (po_distr_stg_indx).po_line_id,
                            lt_po_dist_data (po_distr_stg_indx).DISTRIBUTION_NUM,
                            'NEW SET OF BOOK IS MISSING');
                        lc_master_flag   := gc_error_status;
                    END IF;                    --IF lc_new_sob_id IS NULL THEN
                END IF;

                /*   IF lt_po_dist_data(po_distr_stg_indx).budget_account IS NOT NULL
                   THEN
                      OPEN  cur_get_new_ccid (lt_po_dist_data(po_distr_stg_indx).budget_account);
                      FETCH cur_get_new_ccid INTO ln_budget_acct_id;
                      CLOSE cur_get_new_ccid;

                      IF ln_budget_acct_id IS NULL THEN
                          xxd_common_utils.record_error('PO'
                                                       ,gn_org_id
                                                       ,'XXD Open Purchase Orders Conversion Program'
                                                       ,'New Code combination mapping is missing for budget_account at distribution for code combination => '||lt_po_dist_data(po_distr_stg_indx).budget_account
                                                       ,DBMS_UTILITY.format_error_backtrace
                                                       ,gn_user_id
                                                       ,gn_conc_request_id
                                                       ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                                       , lt_po_dist_data(po_distr_stg_indx).po_line_id
                                                       ,lt_po_dist_data(po_distr_stg_indx).DISTRIBUTION_NUM
                                                      ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                             );
                          lc_master_flag := gc_error_status;
                      END IF; --IF ln_budget_acct_id IS NULL THEN
                   END IF;

                   IF lt_po_dist_data(po_distr_stg_indx).accural_account IS NOT NULL
                   THEN
                      OPEN  cur_get_new_ccid (lt_po_dist_data(po_distr_stg_indx).accural_account);
                      FETCH cur_get_new_ccid INTO ln_accur_accnt_id;
                      CLOSE cur_get_new_ccid;

                      IF ln_accur_accnt_id IS NULL THEN
                          xxd_common_utils.record_error('PO'
                                                       ,gn_org_id
                                                       ,'XXD Open Purchase Orders Conversion Program'
                                                       ,'New Code combination mapping is missing for accural_account at distribution for code combination => '||lt_po_dist_data(po_distr_stg_indx).accural_account
                                                       ,DBMS_UTILITY.format_error_backtrace
                                                       ,gn_user_id
                                                       ,gn_conc_request_id
                                                       ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                                       , lt_po_dist_data(po_distr_stg_indx).po_line_id
                                                       ,lt_po_dist_data(po_distr_stg_indx).DISTRIBUTION_NUM
                                                      ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                             );
                          lc_master_flag := gc_error_status;
                      END IF; --IF accural_account IS NULL THEN
                   END IF;

                   IF lt_po_dist_data(po_distr_stg_indx).variance_account IS NOT NULL
                   THEN
                      OPEN  cur_get_new_ccid (lt_po_dist_data(po_distr_stg_indx).variance_account);
                      FETCH cur_get_new_ccid INTO ln_var_accnt_id;
                      CLOSE cur_get_new_ccid;

                      IF ln_var_accnt_id IS NULL THEN
                          xxd_common_utils.record_error('PO'
                                                       ,gn_org_id
                                                       ,'XXD Open Purchase Orders Conversion Program'
                                                       ,'New Code combination mapping is missing for variance_account at distribution for code combination => '
                                                        ||lt_po_dist_data(po_distr_stg_indx).variance_account
                                                       ,DBMS_UTILITY.format_error_backtrace
                                                       ,gn_user_id
                                                       ,gn_conc_request_id
                                                       ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                                       , lt_po_dist_data(po_distr_stg_indx).po_line_id
                                                       ,lt_po_dist_data(po_distr_stg_indx).DISTRIBUTION_NUM
                                                      ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                             );
                          lc_master_flag := gc_error_status;
                      END IF; --IF variance_account IS NULL THEN
                   END IF;

                   IF lt_po_dist_data(po_distr_stg_indx).dest_charge_account IS NOT NULL
                   THEN
                      OPEN  cur_get_new_ccid (lt_po_dist_data(po_distr_stg_indx).dest_charge_account);
                      FETCH cur_get_new_ccid INTO ln_dest_charge_acct_id;
                      CLOSE cur_get_new_ccid;

                      IF ln_dest_charge_acct_id IS NULL THEN
                          xxd_common_utils.record_error('PO'
                                                       ,gn_org_id
                                                       ,'XXD Open Purchase Orders Conversion Program'
                                                       ,'New Code combination mapping is missing for dest_charge_account at distribution for code combination => '
                                                        ||lt_po_dist_data(po_distr_stg_indx).dest_charge_account
                                                       ,DBMS_UTILITY.format_error_backtrace
                                                       ,gn_user_id
                                                       ,gn_conc_request_id
                                                       ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                                       , lt_po_dist_data(po_distr_stg_indx).po_line_id
                                                       ,lt_po_dist_data(po_distr_stg_indx).DISTRIBUTION_NUM
                                                      ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                             );
                          lc_master_flag := gc_error_status;
                      END IF; --IF dest_charge_account IS NULL THEN
                   END IF;

                   IF lt_po_dist_data(po_distr_stg_indx).dest_variance_account IS NOT NULL
                   THEN
                      OPEN  cur_get_new_ccid (lt_po_dist_data(po_distr_stg_indx).dest_variance_account);
                      FETCH cur_get_new_ccid INTO ln_dest_variance_acct_id;
                      CLOSE cur_get_new_ccid;

                      IF ln_dest_variance_acct_id IS NULL THEN
                          xxd_common_utils.record_error('PO'
                                                       ,gn_org_id
                                                       ,'XXD Open Purchase Orders Conversion Program'
                                                       ,'New Code combination mapping is missing for dest_variance_account at distribution for code combination => '
                                                        ||lt_po_dist_data(po_distr_stg_indx).dest_variance_account
                                                       ,DBMS_UTILITY.format_error_backtrace
                                                       ,gn_user_id
                                                       ,gn_conc_request_id
                                                       ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                                       , lt_po_dist_data(po_distr_stg_indx).po_line_id
                                                       ,lt_po_dist_data(po_distr_stg_indx).DISTRIBUTION_NUM
                                                      ,'NEW CODE COMBINATION MAPPING IS MISSING'
                                             );
                          lc_master_flag := gc_error_status;
                      END IF; --IF dest_variance_account IS NULL THEN
                   END IF;
       */
                write_log (
                    'Master flag to update the dist table ' || lc_master_flag);

                IF lc_master_flag = gc_error_status
                THEN
                    UPDATE XXD_PO_DISTRIBUTIONS_STG_T
                       SET variance_account_id = ln_var_accnt_id, accrual_account_id = ln_accur_accnt_id, budget_account_id = ln_budget_acct_id,
                           record_status = gc_error_status, request_id = gn_conc_request_id
                     WHERE     po_header_id =
                               lt_po_dist_data (po_distr_stg_indx).po_header_id
                           AND po_line_id =
                               lt_po_dist_data (po_distr_stg_indx).po_line_id
                           AND po_distribution_id =
                               lt_po_dist_data (po_distr_stg_indx).po_distribution_id;

                    x_return_flag   := gc_error_status;
                ELSE
                    UPDATE XXD_PO_DISTRIBUTIONS_STG_T
                       SET variance_account_id = ln_var_accnt_id, accrual_account_id = ln_accur_accnt_id, budget_account_id = ln_budget_acct_id,
                           destination_organization_id = lc_new_inv_org_id, dest_charge_account_id = ln_dest_charge_acct_id, dest_variance_account_id = ln_dest_variance_acct_id,
                           set_of_books_id = lc_new_sob_id, record_status = gc_validate_status, request_id = gn_conc_request_id
                     WHERE     po_header_id =
                               lt_po_dist_data (po_distr_stg_indx).po_header_id
                           AND po_line_id =
                               lt_po_dist_data (po_distr_stg_indx).po_line_id
                           AND po_distribution_id =
                               lt_po_dist_data (po_distr_stg_indx).po_distribution_id;
                END IF;
            END LOOP;

            lt_po_dist_data.delete;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'VALIDATE_OPEN_PO_DISTRIBUTIONS failed with exceptions');
            x_return_flag   := gc_error_status;
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --      SQLCODE,
                                                                                                           'VALIDATE_OPEN_PO_DISTRIBUTIONS Exception ' || SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                                        --    SYSDATE,
                                                                                                                                                                                                        gn_user_id, gn_conc_request_id, 'XXD_PO_DISTRIBUTIONS_STG_T', NULL
                                           , NULL);
    END VALIDATE_OPEN_PO_DISTRIBUTIONS;

    PROCEDURE VALIDATE_OPEN_PO_LINES (p_po_header_id   IN     NUMBER,
                                      x_return_flag       OUT VARCHAR2)
    AS
        -- +===================================================================+
        -- | Name  : VALIDATE_OPEN_PO_LINES                                    |
        -- | Description      :  Procedure to validate the purchase order lines|
        -- |                    staging data                                   |
        -- |                                                                   |
        -- | Parameters :   p_po_header_id                                     |
        -- |                                                                   |
        -- | Returns :   x_error_tbl ,  x_return_flag                          |
        -- |                                                                   |
        -- +===================================================================+


        --Cursor for po lines staging
        CURSOR cur_po_line (p_po_header_id VARCHAR2)
        IS
            SELECT DISTINCT xles.po_header_id, xles.po_line_id --                   ,xpll.line_location_id
                                                              , xles.line_num,
                            xles.ship_to_organization_code, xles.ship_to_location, line_type,
                            xles.freight_carrier, xles.freight_terms, item,
                            closed_code, xles.fob, xles.UNIT_OF_MEASURE,
                            xles.quantity, xles.uom_code, xles.need_by_date,
                            xles.category, xles.receiving_routing
              --                    xpll.attribute1 SHIPMENT_ATTRIBUTE1,
              --                    xpll.attribute2 SHIPMENT_ATTRIBUTE2,
              --                    xpll.attribute3 SHIPMENT_ATTRIBUTE3,
              --                    xpll.attribute4 SHIPMENT_ATTRIBUTE4,
              --                    xpll.attribute5 SHIPMENT_ATTRIBUTE5,
              --                    xpll.attribute6 SHIPMENT_ATTRIBUTE6,
              --                    xpll.attribute7 SHIPMENT_ATTRIBUTE7,
              --                    xpll.attribute8 SHIPMENT_ATTRIBUTE8,
              --                    xpll.attribute9 SHIPMENT_ATTRIBUTE9,
              --                    xpll.attribute10 SHIPMENT_ATTRIBUTE10
              FROM XXD_PO_LINES_STG_T xles --,XXD_PO_LINE_LOCATIONS_STG_T xpll
             WHERE xles.po_header_id = p_po_header_id; --AND record_status = 'N';

        --      xles.po_line_id = xpll.po_line_id(+)
        --          AND xles.po_header_id = xpll.po_header_id(+)
        --           AND
        --         SELECT xles.*
        --           FROM XXD_PO_LINES_STG_T xles,XXD_PO_LINE_LOCATIONS_STG_T xpll
        --          WHERE xles.po_header_id = p_po_header_id;

        lc_master_flag               VARCHAR2 (20);
        ln_ship_to_org_id            NUMBER;
        ln_line_type_id              NUMBER;
        lc_freight_carriers          VARCHAR2 (30);
        ln_ships_to_location_id      NUMBER;
        lc_status                    VARCHAR2 (240);
        lc_get_fob_codes             VARCHAR2 (30);
        ln_item_id                   NUMBER;
        ln_category_id               NUMBER;
        x_return_distribution_flag   VARCHAR2 (20);
        lc_rece_routing_name         VARCHAR2 (60);
        lx_uom_code                  VARCHAR2 (60);
        ln_ship_location_id          NUMBER;
        lc_ship_code                 VARCHAR2 (1000);

        TYPE lt_po_line_data_typ IS TABLE OF cur_po_line%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_data              lt_po_line_data_typ;
        --                lt_po_line_data         gtab_po_line;
        lc_error_message             VARCHAR2 (1000);
    BEGIN
        --open po line cursor
        OPEN cur_po_line (p_po_header_id);

        FETCH cur_po_line BULK COLLECT INTO lt_po_line_data;

        CLOSE cur_po_line;

        x_return_flag   := gc_validate_status;
        write_log ('Working VALIDATE_OPEN_PO_LINES');

        IF lt_po_line_data.COUNT > 0
        THEN
            FOR po_line_stg_indx IN lt_po_line_data.FIRST ..
                                    lt_po_line_data.LAST
            LOOP
                lc_master_flag               := gc_validate_status;
                ln_ship_to_org_id            := NULL;
                ln_line_type_id              := NULL;
                lc_freight_carriers          := NULL;
                ln_ships_to_location_id      := NULL;
                lc_status                    := NULL;
                lc_get_fob_codes             := NULL;
                ln_item_id                   := NULL;
                ln_category_id               := NULL;
                x_return_distribution_flag   := NULL;
                lx_uom_code                  := NULL;
                lc_error_message             := NULL;

                --check if ship to organization code
                IF (lt_po_line_data (po_line_stg_indx).ship_to_organization_code)
                       IS NOT NULL
                THEN                        -- Check ship_to_organization_code
                    --                           xxd_common_utils.record_error
                    --                                    ('PO',
                    --                                     gn_org_id,
                    --                                     'XXD Open Purchase Orders Conversion Program',
                    --                               --      SQLCODE,
                    --                                     'Ship To Organization Code has not been provided for PO=> '||lt_po_line_data(po_line_stg_indx).po_header_id ,
                    --                                     DBMS_UTILITY.format_error_backtrace,
                    --                                  --   DBMS_UTILITY.format_call_stack,
                    --                                 --    SYSDATE,
                    --                                    gn_user_id,
                    --                                     gn_conc_request_id,
                    --                                      'SHIP_TO_ORGANIZATION_CODE'
                    --                                       ,'SHIP_TO_ORG_CODE_MISSING'
                    --                                     , lt_po_line_data(po_line_stg_indx).po_header_id
                    --                                     ,lt_po_line_data(po_line_stg_indx).line_num
                    --                                     );
                    --
                    --                       lc_master_flag := gc_error_status;
                    --
                    --                      --update po line staging table with ship to org id from ship to organization code
                    --                    ELSE
                    write_log (
                           'lt_po_line_data(po_line_stg_indx).ship_to_organization_code => '
                        || lt_po_line_data (po_line_stg_indx).ship_to_organization_code);
                    get_ship_to_org_id (
                        lt_po_line_data (po_line_stg_indx).ship_to_organization_code,
                        ln_ship_to_org_id);

                    IF ln_ship_to_org_id IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Ship To Organization Code has not been provided ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Ship To Organization Code has not been provided ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            lt_po_line_data (po_line_stg_indx).ship_to_organization_code);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check if line type is not null
                IF (lt_po_line_data (po_line_stg_indx).line_type) IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' line_type has not been provided for PO ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'line_type has not been provided for PO',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_line_data (po_line_stg_indx).po_header_id,
                        lt_po_line_data (po_line_stg_indx).line_num,
                        'XXD_PO_LINES_STG_T',
                        lt_po_line_data (po_line_stg_indx).line_type);

                    lc_master_flag   := gc_error_status;
                ELSE
                    get_line_type_id (
                        lt_po_line_data (po_line_stg_indx).line_type,
                        ln_line_type_id);

                    --update po line staging table with line type id from line type
                    IF ln_line_type_id IS NULL
                    THEN
                        --                                     UPDATE xxbic_po_lines_stg
                        --                                        SET line_type_id=ln_line_type_id
                        --                                      WHERE interface_header_id=lt_po_hdr_data(po_hdr_stg_indx).interface_header_id
                        --                                        AND interface_line_id=lt_po_line_data(po_line_stg_indx).interface_line_id;
                        --
                        --                        ELSE

                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' line_type has not setup or invalid value provided for PO ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'line_type has not setup or invalid value provided for PO ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            lt_po_line_data (po_line_stg_indx).line_type);
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check if freight carrier is not null
                IF lt_po_line_data (po_line_stg_indx).freight_carrier
                       IS NOT NULL
                THEN
                    get_freight_carrier (
                        lt_po_line_data (po_line_stg_indx).freight_carrier,
                        lc_freight_carriers);

                    --update po line staging table with freigh carrier code from freight carrier
                    IF lc_freight_carriers IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Freight Carrier  has not setup or invalid value provided for PO  ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Freight Carrier  has not setup or invalid value provided for PO ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            lt_po_line_data (po_line_stg_indx).freight_carrier);
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check freight terms is valid
                IF lt_po_line_data (po_line_stg_indx).freight_terms
                       IS NOT NULL
                THEN
                    lc_status   :=
                        check_freight_terms (
                            lt_po_line_data (po_line_stg_indx).freight_terms);

                    IF lc_status <> 'X'
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Freight Terms  has not setup or invalid value provided for PO  ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Freight Terms  has not setup or invalid value provided for PO',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            lt_po_line_data (po_line_stg_indx).freight_terms);
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check if line ship to location is not null
                IF lt_po_line_data (po_line_stg_indx).ship_to_location
                       IS NOT NULL
                THEN
                    lc_ship_code   := NULL;

                    BEGIN
                        SELECT location_id, flv.description
                          INTO ln_ship_location_id, lc_ship_code
                          FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                   , fnd_lookup_values flv
                         WHERE     UPPER (hla.location_code) =
                                   UPPER (flv.description)
                               AND UPPER (flv.meaning) =
                                   --UPPER (sup_rec.ship_to_location_code)
                                   UPPER (
                                       lt_po_line_data (po_line_stg_indx).ship_to_location)
                               AND lookup_type = 'XXDO_CONV_LOCATION_MAPPING'
                               AND language = 'US';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_ship_code   := NULL;
                    END;

                    --Commented by BT Technology team to derive Ship to Location ID at line level on 28-Apr-2015
                    /*get_ship_to_loc_id ( --lt_po_line_data (po_line_stg_indx).ship_to_location,
                                        lc_ship_code,
                                        'SHIP_TO',
                                        ln_ships_to_location_id);*/

                    --Added by BT Technology team to derive Ship to Location ID at line level on 28-Apr-2015
                    get_ship_to_locat_id (ln_ship_to_org_id,
                                          ln_ships_to_location_id);


                    --update po line staging table with ship to location id from ship to location
                    IF ln_ships_to_location_id IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Ship to location  not setup or invalid value provided for PO  ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Ship to location  not setup or invalid value provided for PO',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            lt_po_line_data (po_line_stg_indx).ship_to_location);
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                write_log (
                       'Before get_orcl_item_frm_legacy_item validation ln_ship_to_org_id - '
                    || ln_ship_to_org_id);

                IF ln_ship_to_org_id IS NOT NULL
                THEN
                    --check if item is not null
                    IF (lt_po_line_data (po_line_stg_indx).item) IS NOT NULL
                    THEN                                         -- Check item
                        get_orcl_item_frm_legacy_item (
                            p_item_number   =>
                                lt_po_line_data (po_line_stg_indx).item,
                            p_org_id    => ln_ship_to_org_id,
                            x_item_id   => ln_item_id,
                            x_status    => lc_status);

                        IF ln_item_id IS NULL
                        THEN
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || ' Item Does not exist in the system  ';

                            xxd_common_utils.record_error (
                                'PO',
                                gn_org_id,
                                'XXD Open Purchase Orders Conversion Program',
                                --      SQLCODE,
                                'Item Does not exist in the system ',
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --    SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                lt_po_line_data (po_line_stg_indx).po_header_id,
                                lt_po_line_data (po_line_stg_indx).line_num,
                                'XXD_PO_LINES_STG_T',
                                'CATEGORY_NOT_VALID');

                            lc_master_flag   := gc_error_status;


                            GET_CATEGORY_ID (ln_item_id,
                                             ln_ship_to_org_id,
                                             ln_category_id);
                        --update po line staging table with category id from category
                        /*   IF ln_category_id IS NULL
                            THEN

                    lc_error_message := lc_error_message||','||' Category has not been provided for PO  ';

                               xxd_common_utils.record_error (
                                  'PO',
                                  gn_org_id,
                                  'XXD Open Purchase Orders Conversion Program',
                                  --      SQLCODE,
                                  'Category has not been provided for PO',
                                  DBMS_UTILITY.format_error_backtrace,
                                  --   DBMS_UTILITY.format_call_stack,
                                  --    SYSDATE,
                                  gn_user_id,
                                  gn_conc_request_id,
                                  lt_po_line_data (po_line_stg_indx).po_header_id,
                                  lt_po_line_data (po_line_stg_indx).line_num,
                                  'XXD_PO_LINES_STG_T',
                                  'CATEGORY_NOT_VALID');

                               lc_master_flag := gc_error_status; */
                        --END IF;
                        END IF;
                    END IF;
                END IF;

                --check if closed code is not null
                /*   IF lt_po_line_data (po_line_stg_indx).closed_code IS NULL
                   THEN
                      lc_error_message :=
                            lc_error_message
                         || ','
                         || ' Closed Code in staging table are not valid for PO  ';

                      xxd_common_utils.record_error (
                         'PO',
                         gn_org_id,
                         'XXD Open Purchase Orders Conversion Program',
                         --      SQLCODE,
                         'Closed Code in staging table are not valid for PO',
                         DBMS_UTILITY.format_error_backtrace,
                         --   DBMS_UTILITY.format_call_stack,
                         --    SYSDATE,
                         gn_user_id,
                         gn_conc_request_id,
                         lt_po_line_data (po_line_stg_indx).po_header_id,
                         lt_po_line_data (po_line_stg_indx).line_num,
                         'XXD_PO_LINES_STG_T',
                         'CLOSED_CODE_NOT_VALID');
                      lc_master_flag := gc_error_status;
                   END IF; */

                --update po line staging table with fob code from fob
                IF lt_po_line_data (po_line_stg_indx).fob IS NOT NULL
                THEN
                    get_fob_code (lt_po_line_data (po_line_stg_indx).fob,
                                  lc_get_fob_codes);

                    IF lc_get_fob_codes IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' FOB Code in staging table are not valid for PO  ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'FOB Code in staging table are not valid for PO',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            'FOB_ERROR');
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check uom code is not null
                IF (lt_po_line_data (po_line_stg_indx).UNIT_OF_MEASURE)
                       IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' UOM Code in staging table are not valid for PO ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'UOM Code in staging table are not valid for PO',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_line_data (po_line_stg_indx).po_header_id,
                        lt_po_line_data (po_line_stg_indx).line_num,
                        'XXD_PO_LINES_STG_T',
                        'UOM_CODE_MISSING');
                    lc_master_flag   := gc_error_status;
                ELSE
                    lc_status   :=
                        check_uom (
                            lt_po_line_data (po_line_stg_indx).UNIT_OF_MEASURE);

                    GET_UOM (
                        p_uom_code   =>
                            lt_po_line_data (po_line_stg_indx).UNIT_OF_MEASURE,
                        x_uom_code   => lx_uom_code);

                    IF lc_status <> 'X'
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' UOM Code in staging table are not valid ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'UOM Code in staging table are not valid ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_line_data (po_line_stg_indx).po_header_id,
                            lt_po_line_data (po_line_stg_indx).line_num,
                            'XXD_PO_LINES_STG_T',
                            'UOM_CODE_MISSING');
                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --check id quantity is not null
                IF (lt_po_line_data (po_line_stg_indx).quantity) IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' Quantity has not provided in staging table are not valid ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'Quantity has not provided in staging table are not valid ',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_line_data (po_line_stg_indx).po_header_id,
                        lt_po_line_data (po_line_stg_indx).line_num,
                        'XXD_PO_LINES_STG_T',
                        'QUANTITY_MISSING');
                    lc_master_flag   := gc_error_status;
                END IF;

                --check id receiving_routing is not null
                IF (lt_po_line_data (po_line_stg_indx).receiving_routing)
                       IS NOT NULL
                THEN
                    lc_rece_routing_name   := NULL;

                    BEGIN
                        SELECT receiving_routing_name
                          INTO lc_rece_routing_name
                          FROM pofv_receiving_routings
                         WHERE receiving_routing_name =
                               lt_po_line_data (po_line_stg_indx).receiving_routing;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || ' Receiving routing provided in staging table are not valid ';

                            xxd_common_utils.record_error (
                                'PO',
                                gn_org_id,
                                'XXD Open Purchase Orders Conversion Program',
                                --      SQLCODE,
                                'Receiving routing provided in staging table are not valid  ',
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --    SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                lt_po_line_data (po_line_stg_indx).po_header_id,
                                lt_po_line_data (po_line_stg_indx).line_num,
                                'XXD_PO_LINES_STG_T',
                                'RECEIVING_ROUTING_NAME MISSING');
                            lc_master_flag   := gc_error_status;
                    END;
                END IF;


                x_return_distribution_flag   := gc_validate_status;

                write_log (
                       'Calling VALIDATE_OPEN_PO_DISTRIBUTIONS for po header '
                    || lt_po_line_data (po_line_stg_indx).po_header_id
                    || ' and line '
                    || lt_po_line_data (po_line_stg_indx).po_line_id);

                /*     VALIDATE_OPEN_PO_DISTRIBUTIONS(p_po_header_id      =>     lt_po_line_data(po_line_stg_indx).po_header_id
                                                                                             ,p_po_line_id           =>     lt_po_line_data(po_line_stg_indx).po_line_id
                                                                                             ,p_item_id                =>    ln_item_id
                                                                                             ,p_ship_to_org_id   =>    ln_ship_to_org_id
                                                                                             ,x_return_flag           =>    x_return_distribution_flag
                                                                               ); */
                --                    x_return_locations_flag   := gc_validate_status ;


                IF    lc_master_flag = gc_error_status
                   OR x_return_distribution_flag = gc_error_status
                THEN
                    UPDATE XXD_PO_LINES_STG_T
                       SET fob = lc_get_fob_codes, ship_to_location_id = ln_ships_to_location_id, freight_carrier = lc_freight_carriers,
                           line_type_id = ln_line_type_id, item_id = ln_item_id, category_id = ln_category_id,
                           ship_to_organization_id = ln_ship_to_org_id, UOM_CODE = lx_uom_code, record_status = gc_error_status,
                           request_id = gn_conc_request_id, error_message1 = lc_error_message
                     WHERE     po_header_id =
                               lt_po_line_data (po_line_stg_indx).po_header_id
                           AND po_line_id =
                               lt_po_line_data (po_line_stg_indx).po_line_id;



                    x_return_flag   := gc_error_status;

                    --                                      UPDATE XXD_PO_LINE_LOCATIONS_STG_T
                    --                                              SET  ship_to_organization_id   = ln_ship_to_org_id,
                    --                                              ship_to_location_id       = ln_ships_to_location_id,
                    --                                           record_status     = gc_error_status
                    --                                           , request_id = gn_conc_request_id
                    --                                     WHERE po_header_id = lt_po_line_data(po_line_stg_indx).po_header_id
                    --                                           AND po_line_id = lt_po_line_data (po_line_stg_indx).po_line_id
                    --                                           AND line_location_id =  lt_po_line_data (po_line_stg_indx).line_location_id;

                    UPDATE XXD_PO_HEADERS_STG_T
                       SET record_status = gc_error_status, error_message2 = 'Child record failed for one of the validation '
                     WHERE po_header_id =
                           lt_po_line_data (po_line_stg_indx).po_header_id;

                    UPDATE XXD_PO_LINES_STG_T
                       SET record_status = gc_error_status, error_message2 = 'One of the Child record failed for one of the validation '
                     WHERE po_header_id =
                           lt_po_line_data (po_line_stg_indx).po_header_id;
                ELSE
                    UPDATE XXD_PO_LINES_STG_T
                       SET fob = lc_get_fob_codes, ship_to_location_id = ln_ships_to_location_id, freight_carrier = lc_freight_carriers,
                           line_type_id = ln_line_type_id, item_id = ln_item_id, category_id = ln_category_id,
                           ship_to_organization_id = ln_ship_to_org_id, UOM_CODE = lx_uom_code, record_status = gc_validate_status,
                           request_id = gn_conc_request_id
                     WHERE     po_header_id =
                               lt_po_line_data (po_line_stg_indx).po_header_id
                           AND po_line_id =
                               lt_po_line_data (po_line_stg_indx).po_line_id;
                --                                      UPDATE XXD_PO_LINE_LOCATIONS_STG_T
                --                                              SET  ship_to_organization_id   = ln_ship_to_org_id,
                --                                              ship_to_location_id       = ln_ships_to_location_id,
                --                                           record_status     = gc_validate_status
                --                                           , request_id = gn_conc_request_id
                --                                     WHERE po_header_id = lt_po_line_data(po_line_stg_indx).po_header_id
                --                                           AND po_line_id = lt_po_line_data (po_line_stg_indx).po_line_id
                --                                           AND line_location_id =  lt_po_line_data (po_line_stg_indx).line_location_id;


                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('VALIDATE_OPEN_PO_LINES failed with exceptions');
            x_return_flag   := gc_error_status;
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --      SQLCODE,
                                                                                                           'VALIDATE_OPEN_PO_LINES Exception ' || SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                                --    SYSDATE,
                                                                                                                                                                                                gn_user_id, gn_conc_request_id, NULL, NULL
                                           , 'XXD_PO_LINES_STG_T');
    END VALIDATE_OPEN_PO_LINES;

    PROCEDURE VALIDATE_OPEN_PO (p_debug IN VARCHAR2 DEFAULT 'N', p_batch_id IN NUMBER, p_process_mode IN VARCHAR2
                                , p_request_id IN NUMBER --   ,x_return_flag    OUT NOCOPY    VARCHAR2
                                                        )
    -- +===================================================================+
    -- | Name  : VALIDATE_MAIN                                             |
    -- | Description      : Main Procedure to validate the purchase order  |
    -- |                    staging data                                   |
    -- |                                                                   |
    -- | Parameters : p_batch_id, p_debug, p_process_mode,p_request_id     |
    -- |                                                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :     x_return_flag                                       |
    -- |                                                                   |
    -- +===================================================================+
    IS
        --local variables
        lc_master_flag            VARCHAR2 (20);
        lx_line_status            VARCHAR2 (20);
        ln_organization_id        NUMBER;
        lc_status                 VARCHAR2 (240);
        ln_org_id                 NUMBER;
        ln_ship_to_location_id    NUMBER;
        ln_bill_to_location_id    NUMBER;
        ln_term_id                NUMBER;
        ln_agent_id               NUMBER;
        ln_vendor_id              NUMBER;
        ln_vendor_site_id         NUMBER;
        lc_vendor_site_code       VARCHAR2 (30);
        lc_freight_carrier        VARCHAR2 (30);
        lc_freight_terms          VARCHAR2 (30);
        lc_get_fob_code           VARCHAR2 (30);
        ln_contact_id             NUMBER;
        ln_ship_to_org_id         NUMBER;
        ln_vendors_id             NUMBER;
        ln_ships_to_location_id   NUMBER;
        lt_po_hdr_data            gtab_po_header;
        lc_bill_code              VARCHAR2 (1000);
        lc_ship_code              VARCHAR2 (1000);
        ln_ship_location_id       NUMBER;
        ln_ship_to_org_code       VARCHAR2 (240); --Added by BT Technology Team to store Ship to Org Code for PO Headers on 28-Apr-2015

        --cursor for po headers staging
        CURSOR cur_po_hdr IS
            SELECT xhes.*
              FROM XXD_PO_HEADERS_STG_T xhes
             WHERE     xhes.record_status IN (gc_new_status, gc_error_status)
                   AND xhes.batch_id = p_batch_id;

        lc_error_message          VARCHAR2 (1000);
    BEGIN
        --IF p_process_mode = gc_create THEN

        --fnd_file.put_line (fnd_file.LOG, 'Test1 ');

        OPEN cur_po_hdr;

        FETCH cur_po_hdr BULK COLLECT INTO lt_po_hdr_data;

        CLOSE cur_po_hdr;

        IF lt_po_hdr_data.COUNT > 0
        THEN
            FOR po_hdr_stg_indx IN lt_po_hdr_data.FIRST ..
                                   lt_po_hdr_data.LAST
            LOOP
                lc_error_message   := NULL;
                lc_master_flag     := gc_validate_status;
                write_log (
                       'Validation for open po'
                    || lt_po_hdr_data (po_hdr_stg_indx).po_number);

                --Check if currency code is not null
                IF (lt_po_hdr_data (po_hdr_stg_indx).currency_code) IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' Currency Code has not been provided ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        'Currency Code has not been provided ',
                        DBMS_UTILITY.format_error_backtrace,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                        'XXD_PO_HEADERS_STG_T',
                        lt_po_hdr_data (po_hdr_stg_indx).currency_code);

                    lc_master_flag   := gc_error_status;
                --Check if currency code valid lookup
                ELSE
                    lc_status   := NULL;
                    lc_status   :=
                        check_currency (
                            lt_po_hdr_data (po_hdr_stg_indx).currency_code);

                    IF lc_status <> 'X'
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Currency Code is not derived in the system ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            'Currency Code is not derived in the system ',
                            DBMS_UTILITY.format_error_backtrace,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).currency_code);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --Check if org id is not null
                IF (lt_po_hdr_data (po_hdr_stg_indx).OU_NAME) IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' OU_NAME has not been provided ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'OU_NAME has not been provided ',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                        'XXD_PO_HEADERS_STG_T',
                        lt_po_hdr_data (po_hdr_stg_indx).OU_NAME);

                    lc_master_flag   := gc_error_status;
                --update header staging table with org id from organization name
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OU_NAME '
                        || lt_po_hdr_data (po_hdr_stg_indx).OU_NAME);
                    get_org_id (lt_po_hdr_data (po_hdr_stg_indx).OU_NAME,
                                ln_org_id);

                    IF ln_org_id IS NOT NULL
                    THEN
                        -- write_log('Inside ln_org_id IS NOT NULL');
                        --check if vendor name is not null
                        IF (lt_po_hdr_data (po_hdr_stg_indx).vendor_name)
                               IS NULL
                        THEN
                            --   write_log('Inside vendor_name IS NULL');
                            --check if vendor number is not null
                            IF (lt_po_hdr_data (po_hdr_stg_indx).vendor_number)
                                   IS NULL
                            THEN
                                --write_log('Inside vendor_number IS NULL');
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Vendor Name or Vendor Number should be provided ';

                                xxd_common_utils.record_error (
                                    'PO',
                                    gn_org_id,
                                    'XXD Open Purchase Orders Conversion Program',
                                    'Vendor Name or Vendor Number should be provided ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                    'XXD_PO_HEADERS_STG_T',
                                    lt_po_hdr_data (po_hdr_stg_indx).vendor_number);

                                lc_master_flag   := gc_error_status;
                            --update header staging table with vendor id from vendor number
                            ELSE
                                --  write_log('Getting get_vendor_id - getting Vendor_id from vendor number ');
                                --  write_log('vendor_number :'||lt_po_hdr_data (po_hdr_stg_indx).vendor_number);
                                get_vendor_id (
                                    lt_po_hdr_data (po_hdr_stg_indx).vendor_number,
                                    ln_vendor_id);

                                IF ln_vendor_id IS NULL
                                THEN
                                    --write_log('Inside ln_vendor_id IS NULL ');
                                    lc_error_message   :=
                                           lc_error_message
                                        || ','
                                        || ' Vendor Number Not valid ';

                                    xxd_common_utils.record_error (
                                        'PO',
                                        gn_org_id,
                                        'XXD Open Purchase Orders Conversion Program',
                                        'Vendor Number Not valid ',
                                        DBMS_UTILITY.format_error_backtrace,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                        'XXD_PO_HEADERS_STG_T',
                                        lt_po_hdr_data (po_hdr_stg_indx).vendor_number);

                                    lc_master_flag   := gc_error_status;
                                END IF;
                            END IF;
                        --update header staging table with vendor id from vendor name
                        ELSE
                            --write_log('Inside getting Vendor_id from vendor name');
                            get_vendors_id (
                                lt_po_hdr_data (po_hdr_stg_indx).vendor_name,
                                ln_vendors_id);

                            IF ln_vendors_id IS NULL
                            THEN
                                --write_log('IF ln_vendors_id IS NULL');
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Vendor Name Not valid ';

                                xxd_common_utils.record_error (
                                    'PO',
                                    gn_org_id,
                                    'XXD Open Purchase Orders Conversion Program',
                                    --      SQLCODE,
                                    'Vendor Name Not valid ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                    --    SYSDATE,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                    'XXD_PO_HEADERS_STG_T',
                                    lt_po_hdr_data (po_hdr_stg_indx).vendor_name);

                                lc_master_flag   := gc_error_status;
                            END IF;
                        END IF;

                        --check if vendor site code is not null
                        IF (lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code)
                               IS NULL
                        THEN
                            --write_log('Inside vendor site code is null');
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || ' Vendor Site has not been provided ';

                            xxd_common_utils.record_error (
                                'PO',
                                gn_org_id,
                                'XXD Open Purchase Orders Conversion Program',
                                --      SQLCODE,
                                'Vendor Site has not been provided ',
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --    SYSDATE,
                                gn_user_id,
                                gn_conc_request_id,
                                lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                'XXD_PO_HEADERS_STG_T',
                                lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code);

                            lc_master_flag   := gc_error_status;
                        --update header staging table with vendor site id from vendor site code
                        ELSE
                            --write_log('Inside vendor site code is not null');
                            -- write_log('lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code :'||lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code);
                            -- write_log('ln_org_id :'||ln_org_id);
                            -- write_log('ln_vendors_id :'||ln_vendors_id);
                            -- write_log('ln_vendor_id :'||ln_vendor_id);

                            get_vendor_site_id (lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code, ln_org_id, NVL (ln_vendors_id, ln_vendor_id)
                                                , ln_vendor_site_id);

                            --fnd_file.put_line (fnd_file.LOG,                                        'ln_vendors_id ' || ln_vendors_id);

                            --fnd_file.put_line (fnd_file.LOG,                                        'ln_vendor_id ' || ln_vendor_id);

                            --fnd_file.put_line (fnd_file.LOG,                                        'ln_org_id ' || ln_org_id);

                            --fnd_file.put_line (                        fnd_file.LOG,                           'vendor_site_code '                        || lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code);

                            --fnd_file.put_line (                        fnd_file.LOG,                        'ln_vendor_site_id ' || ln_vendor_site_id);


                            IF ln_vendor_site_id IS NOT NULL
                            THEN
                                IF lt_po_hdr_data (po_hdr_stg_indx).vendor_contact
                                       IS NOT NULL
                                THEN
                                    get_vendor_contact_id (lt_po_hdr_data (po_hdr_stg_indx).vendor_contact, ln_vendor_site_id, NVL (ln_vendors_id, ln_vendor_id)
                                                           , ln_contact_id);

                                    IF ln_contact_id IS NULL
                                    THEN
                                        lc_error_message   :=
                                               lc_error_message
                                            || ','
                                            || ' Vendor Contact Not valid ';

                                        xxd_common_utils.record_error (
                                            'PO',
                                            gn_org_id,
                                            'XXD Open Purchase Orders Conversion Program',
                                            --      SQLCODE,
                                            'Vendor Contact Not valid  ',
                                            DBMS_UTILITY.format_error_backtrace,
                                            --   DBMS_UTILITY.format_call_stack,
                                            --    SYSDATE,
                                            gn_user_id,
                                            gn_conc_request_id,
                                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                            'XXD_PO_HEADERS_STG_T',
                                            lt_po_hdr_data (po_hdr_stg_indx).vendor_contact);

                                        lc_master_flag   := gc_error_status;
                                    END IF;
                                END IF;
                            ELSE
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Vendor Site id Not valid ';

                                xxd_common_utils.record_error (
                                    'PO',
                                    gn_org_id,
                                    'XXD Open Purchase Orders Conversion Program',
                                    --      SQLCODE,
                                    'Vendor Site id Not valid ',
                                    DBMS_UTILITY.format_error_backtrace,
                                    --   DBMS_UTILITY.format_call_stack,
                                    --    SYSDATE,
                                    gn_user_id,
                                    gn_conc_request_id,
                                    lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                                    'XXD_PO_HEADERS_STG_T',
                                    lt_po_hdr_data (po_hdr_stg_indx).vendor_site_code,
                                    lt_po_hdr_data (po_hdr_stg_indx).vendor_name);

                                lc_master_flag   := gc_error_status;
                            END IF;
                        END IF;
                    ELSE
                        lc_error_message   :=
                            lc_error_message || ',' || ' Org Id Not valid ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Org Id Not valid ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).org_id);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test100 ');

                --check if freight carrier is not null
                IF lt_po_hdr_data (po_hdr_stg_indx).freight_carrier IS NULL
                THEN
                    NULL;
                --              xxd_common_utils.record_error
                --                                    ('PO',
                --                                     gn_org_id,
                --                                     'XXD Open Purchase Orders Conversion Program',
                --                               --      SQLCODE,
                --                                    'Freight Carrier has not been provided for PO=>'||lt_po_hdr_data(po_hdr_stg_indx).po_number,
                --                                     DBMS_UTILITY.format_error_backtrace,
                --                                  --   DBMS_UTILITY.format_call_stack,
                --                                 --    SYSDATE,
                --                                    gn_user_id,
                --                                     gn_conc_request_id,
                --                                      'FREIGHT_CARRIER'
                --                                       , 'FREIGHT_CARRIER_MISSING'
                --                                     ,lt_po_hdr_data(po_hdr_stg_indx).freight_carrier
                --                                    );
                --
                --                       lc_master_flag := gc_error_status;
                --update header staging table with freight carrier code from freight carrier name
                ELSIF lt_po_hdr_data (po_hdr_stg_indx).freight_carrier
                          IS NOT NULL
                THEN
                    get_freight_carrier (
                        lt_po_hdr_data (po_hdr_stg_indx).freight_carrier,
                        lc_freight_carrier);

                    IF lc_freight_carrier IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Freight Carrier has not been provided ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Freight Carrier has not been provided ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).freight_carrier);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test101 ');

                --check if freight terms is not null
                IF lt_po_hdr_data (po_hdr_stg_indx).freight_terms IS NULL
                THEN
                    NULL;
                --                      xxd_common_utils.record_error
                --                                    ('PO',
                --                                     gn_org_id,
                --                                     'XXD Open Purchase Orders Conversion Program',
                --                               --      SQLCODE,
                --                                     'Freight Terms has not been provided for PO=>'||lt_po_hdr_data(po_hdr_stg_indx).po_number,
                --                                     DBMS_UTILITY.format_error_backtrace,
                --                                  --   DBMS_UTILITY.format_call_stack,
                --                                 --    SYSDATE,
                --                                    gn_user_id,
                --                                     gn_conc_request_id,
                --                                      'FREIGHT_TERMS'
                --                                       , 'FREIGHT_TERMS_MISSING'
                --                                     ,lt_po_hdr_data(po_hdr_stg_indx).freight_terms
                --                                    );
                --
                --                       lc_master_flag := gc_error_status;
                --check if freight terms is valid
                ELSIF lt_po_hdr_data (po_hdr_stg_indx).freight_terms
                          IS NOT NULL
                THEN
                    lc_status   :=
                        check_freight_terms (
                            lt_po_hdr_data (po_hdr_stg_indx).freight_terms);

                    IF lc_status <> 'X'
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Freight Terms in staging table are not valid ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               --      SQLCODE,
                               'Freight Terms in staging table are not valid '
                            || lt_po_hdr_data (po_hdr_stg_indx).po_number,
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).freight_terms);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test102 ');

                --check if ship to location is not null
                IF (lt_po_hdr_data (po_hdr_stg_indx).ship_to_location)
                       IS NULL
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' SHIP_TO_LOCATION_MISSING ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'SHIP_TO_LOCATION_MISSING',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                        'XXD_PO_HEADERS_STG_T',
                        lt_po_hdr_data (po_hdr_stg_indx).ship_to_location);

                    lc_master_flag   := gc_error_status;
                --update header staging table with ship to location id from ship to location
                ELSE
                    BEGIN
                        SELECT                                  --location_id,
                               flv.description
                          INTO                          --ln_ship_location_id,
                               lc_ship_code
                          FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                   , fnd_lookup_values flv
                         WHERE     UPPER (hla.location_code) =
                                   UPPER (flv.description)
                               AND UPPER (flv.meaning) =
                                   --UPPER (sup_rec.ship_to_location_code)
                                   UPPER (
                                       lt_po_hdr_data (po_hdr_stg_indx).ship_to_location)
                               AND lookup_type = 'XXDO_CONV_LOCATION_MAPPING'
                               AND language = 'US';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_ship_code   := NULL;
                    END;

                    --Commented by BT Technology Team to derive the Ship To Loc ID at Header level on 28-Apr-2015
                    /* get_ship_to_loc_id ( --lt_po_hdr_data (po_hdr_stg_indx).ship_to_location,
                                         lc_ship_code,
                                         'SHIP_TO',
                                         ln_ship_to_location_id);*/

                    --Start of Changes by BT Technology Team to derive the Ship To Loc ID at Header level on 28-Apr-2015
                    /* SELECT ood.organization_code
                       INTO ln_ship_to_org_code
                       FROM org_organization_definitions@bt_read_1206 ood,
                            po_line_locations_all@bt_read_1206 pll
                      WHERE     pll.po_header_id =
                                   lt_po_hdr_data (po_hdr_stg_indx).po_header_id
                            AND ood.organization_id = pll.ship_to_organization_id
                            AND ROWNUM = 1;*/
                    --Removed DB Link table and getting ship_to_organization_code from PO_Lines_Stg table for that PO Header ID
                    SELECT ship_to_organization_code
                      INTO ln_ship_to_org_code
                      FROM xxd_po_lines_stg_t
                     WHERE     po_header_id =
                               lt_po_hdr_data (po_hdr_stg_indx).po_header_id
                           AND ROWNUM = 1;

                    get_ship_to_org_id (ln_ship_to_org_code,
                                        ln_ship_to_org_id); --Added Function to retrieve Ship to Org ID to be passed to next function get_ship_to_locat_id on 28-Apr-2015

                    get_ship_to_locat_id (ln_ship_to_org_id,
                                          ln_ship_to_location_id); --Added Function to derive the Ship To Loc ID at Header level on 28-Apr-2015


                    --End of Changes by BT Technology Team to derive the Ship To Loc ID at Header level on 28-Apr-2015

                    IF ln_ship_to_location_id IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Ship To Location has not been provided ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Ship To Location has not been provided ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).ship_to_location);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test103 ');

                --update header staging table with bill to location id from bill to location
                IF (lt_po_hdr_data (po_hdr_stg_indx).bill_to_location)
                       IS NOT NULL
                THEN
                    lc_bill_code   := NULL;

                    BEGIN
                        SELECT location_id, flv.description
                          INTO ln_ship_location_id, lc_bill_code
                          FROM hr_locations_all hla --Code modification on 05-MAR-2015
                                                   , fnd_lookup_values flv
                         WHERE     UPPER (hla.location_code) =
                                   UPPER (flv.description)
                               AND UPPER (flv.meaning) =
                                   --UPPER (sup_rec.ship_to_location_code)
                                   UPPER (
                                       lt_po_hdr_data (po_hdr_stg_indx).bill_to_location)
                               AND lookup_type = 'XXDO_CONV_LOCATION_MAPPING'
                               AND language = 'US';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_bill_code   := NULL;
                    END;

                    --Commented by BT Technology team to derive Bill to Location ID on 28-Apr-2015
                    /* get_ship_to_loc_id ( --lt_po_hdr_data (po_hdr_stg_indx).bill_to_location,
                                         lc_bill_code,
                                         'BILL_TO',
                                         ln_bill_to_location_id);*/

                    --Added by BT Technology team to derive Bill to Location ID on 28-Apr-2015
                    -- write_log ('ln_vendor_site_id :'||ln_vendor_site_id);
                    get_bill_to_locat_id (ln_vendor_site_id,
                                          ln_bill_to_location_id);


                    IF ln_bill_to_location_id IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ',' -- || ' Bill To Location in staging table are not valid '; --Commented by BT Technology Team on 06-May-2015
                            || 'VENDOR_SITE_CODE in staging table is not valid '; --Added by BT Technology Team on 06-May-2015

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            -- 'Bill To Location in staging table are not valid ',  --Commented by BT Technology Team on 06-May-2015
                            'VENDOR_SITE_CODE in staging table is not valid', --Added by BT Technology Team on 06-May-2015
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            -- lt_po_hdr_data (po_hdr_stg_indx).bill_to_location);   --Commented by BT Technology Team on 06-May-2015
                            lt_po_hdr_data (po_hdr_stg_indx).VENDOR_SITE_CODE); --Added by BT Technology Team on 06-May-2015

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test104 ');

                /*      --check if payment terms is not null
                      IF (lt_po_hdr_data (po_hdr_stg_indx).payment_terms) IS NULL
                      THEN
                         xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                               --      SQLCODE,
                               'Payment Terms has not been provided ',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).payment_terms);

                         lc_master_flag := gc_error_status;
                      --update header staging table with terms id from payment terms
                      ELSE
                         get_terms_id (lt_po_hdr_data (po_hdr_stg_indx).payment_terms,
                                       ln_term_id);

                         IF ln_term_id IS NULL
                         THEN
                            xxd_common_utils.record_error (
                               'PO',
                               gn_org_id,
                               'XXD Open Purchase Orders Conversion Program',
                                  --      SQLCODE,
                                  'Payment Terms in staging table are not valid ',
                               DBMS_UTILITY.format_error_backtrace,
                               --   DBMS_UTILITY.format_call_stack,
                               --    SYSDATE,
                               gn_user_id,
                               gn_conc_request_id,
                               lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                               'XXD_PO_HEADERS_STG_T',
                               lt_po_hdr_data (po_hdr_stg_indx).payment_terms);

                            lc_master_flag := gc_error_status;
                         END IF;
                      END IF; */

                --check if agent name is not null
                IF (lt_po_hdr_data (po_hdr_stg_indx).agent_name) IS NULL
                THEN                                       -- Check Agent_Name
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || ' Agent Name has not been provided ';

                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --      SQLCODE,
                        'Agent Name has not been provided ',
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                        'XXD_PO_HEADERS_STG_T',
                        lt_po_hdr_data (po_hdr_stg_indx).agent_name);

                    lc_master_flag   := gc_error_status;
                --update header staging table with agent id from agent name
                ELSE
                    get_agent_id (
                        lt_po_hdr_data (po_hdr_stg_indx).agent_name,
                        ln_agent_id);

                    IF ln_agent_id IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' Agent Name in staging table are not valid ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'Agent Name in staging table are not valid',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).agent_name);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG, 'Test105 ');

                --check if fob is not null
                IF (lt_po_hdr_data (po_hdr_stg_indx).fob) IS NULL
                THEN
                    NULL;
                --                 xxd_common_utils.record_error
                --                                    ('PO',
                --                                     gn_org_id,
                --                                     'XXD Open Purchase Orders Conversion Program',
                --                               --      SQLCODE,
                --                                     'FOB has not been provided for PO=>'||lt_po_hdr_data(po_hdr_stg_indx).po_number ,
                --                                     DBMS_UTILITY.format_error_backtrace,
                --                                  --   DBMS_UTILITY.format_call_stack,
                --                                 --    SYSDATE,
                --                                    gn_user_id,
                --                                     gn_conc_request_id,
                --                                      'FOB'
                --                                       ,'FOB_MISSING'
                --                                     ,lt_po_hdr_data(po_hdr_stg_indx).fob
                --                                    );
                --
                --                                    lc_master_flag := gc_error_status;

                --update header staging table with fob code from fob name
                ELSIF (lt_po_hdr_data (po_hdr_stg_indx).fob) IS NOT NULL
                THEN
                    get_fob_code (lt_po_hdr_data (po_hdr_stg_indx).fob,
                                  lc_get_fob_code);

                    IF lc_get_fob_code IS NULL
                    THEN
                        lc_error_message   :=
                               lc_error_message
                            || ','
                            || ' FOB in staging table are not valid ';

                        xxd_common_utils.record_error (
                            'PO',
                            gn_org_id,
                            'XXD Open Purchase Orders Conversion Program',
                            --      SQLCODE,
                            'FOB in staging table are not valid',
                            DBMS_UTILITY.format_error_backtrace,
                            --   DBMS_UTILITY.format_call_stack,
                            --    SYSDATE,
                            gn_user_id,
                            gn_conc_request_id,
                            lt_po_hdr_data (po_hdr_stg_indx).PO_HEADER_ID,
                            'XXD_PO_HEADERS_STG_T',
                            lt_po_hdr_data (po_hdr_stg_indx).fob);

                        lc_master_flag   := gc_error_status;
                    END IF;
                END IF;

                --fnd_file.put_line (fnd_file.LOG,                               'lc_master_flag ' || lc_master_flag);
                --fnd_file.put_line (               fnd_file.LOG,                  'Header id out '               || lt_po_hdr_data (po_hdr_stg_indx).po_header_id);
                lx_line_status     := gc_validate_status;

                IF lc_master_flag = gc_error_status
                THEN
                    --fnd_file.put_line (                  fnd_file.LOG,                     'Header id in '                  || lt_po_hdr_data (po_hdr_stg_indx).po_header_id);

                    UPDATE XXD_PO_LINES_STG_T
                       SET record_status = 'E', error_message2 = 'Failed for header validation '
                     WHERE po_header_id =
                           lt_po_hdr_data (po_hdr_stg_indx).po_header_id;
                ELSE
                    --- Call line validate function to validate the line data
                    VALIDATE_OPEN_PO_LINES (
                        p_po_header_id   =>
                            lt_po_hdr_data (po_hdr_stg_indx).po_header_id,
                        x_return_flag   => lx_line_status);
                END IF;

                --Check if approved_date is null then update sysdate
                IF    lc_master_flag = gc_error_status
                   OR lx_line_status = gc_error_status
                THEN
                    UPDATE XXD_PO_HEADERS_STG_T
                       SET ORGS_ID = ln_org_id, vendor_id = ln_vendor_id, vendor_site_id = ln_vendor_site_id,
                           vendor_contact_id = ln_contact_id, freight_carrier = lc_freight_carrier, ship_to_location_id = ln_ship_to_location_id,
                           bill_to_location_id = ln_bill_to_location_id, terms_id = ln_term_id, agent_id = ln_agent_id,
                           fob = lc_get_fob_code, record_status = gc_error_status, request_id = gn_conc_request_id,
                           --batch_id = NULL,
                           error_message1 = lc_error_message
                     WHERE po_header_id =
                           lt_po_hdr_data (po_hdr_stg_indx).po_header_id;


                    UPDATE XXD_PO_DISTRIBUTIONS_STG_T
                       SET org_id   = ln_org_id
                     WHERE po_header_id =
                           lt_po_hdr_data (po_hdr_stg_indx).po_header_id;
                ELSE
                    UPDATE XXD_PO_HEADERS_STG_T
                       SET ORGS_ID = ln_org_id, vendor_id = ln_vendor_id, vendor_site_id = ln_vendor_site_id,
                           vendor_contact_id = ln_contact_id, freight_carrier = lc_freight_carrier, ship_to_location_id = ln_ship_to_location_id,
                           bill_to_location_id = ln_bill_to_location_id, terms_id = ln_term_id, agent_id = ln_agent_id,
                           fob = lc_get_fob_code, record_status = gc_validate_status, request_id = gn_conc_request_id
                     WHERE po_header_id =
                           lt_po_hdr_data (po_hdr_stg_indx).po_header_id;


                    UPDATE XXD_PO_DISTRIBUTIONS_STG_T
                       SET org_id   = ln_org_id
                     WHERE po_header_id =
                           lt_po_hdr_data (po_hdr_stg_indx).po_header_id;
                END IF;

                COMMIT;
            END LOOP;                         --End loop for po headers cursor
        END IF;

        lt_po_hdr_data.delete;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('VALIDATE_OPEN_PO failed with exceptions');

            --x_return_flag                                  := gc_error_status;
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --      SQLCODE,
                                                                                                           'VALIDATE_OPEN_PO Exception ' || SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                          --    SYSDATE,
                                                                                                                                                                                          gn_user_id, gn_conc_request_id, NULL, NULL
                                           , 'FOB_NOT_VALID');
    END VALIDATE_OPEN_PO;

    PROCEDURE submit_po_request (p_batch_id        IN     NUMBER,
                                 p_org_id          IN     NUMBER,
                                 p_submit_openpo      OUT VARCHAR2)
    -- +===================================================================+
    -- | Name  : SUBMIT_PO_REQUEST                                         |
    -- | Description      : Main Procedure to submit the purchase order    |
    -- |                    request                                        |
    -- |                                                                   |
    -- | Parameters : p_submit_openpo                                      |
    -- |                                                                   |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :                                                         |
    -- |                                                                   |
    -- +===================================================================+
    IS
        ln_request_id              NUMBER := 0;

        lc_openpo_hdr_phase        VARCHAR2 (50);
        lc_openpo_hdr_status       VARCHAR2 (100);
        lc_openpo_hdr_dev_phase    VARCHAR2 (100);
        lc_openpo_hdr_dev_status   VARCHAR2 (100);
        lc_openpo_hdr_message      VARCHAR2 (3000);
        lc_submit_openpo           VARCHAR2 (10) := 'N';
        lb_openpo_hdr_req_wait     BOOLEAN;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'p_org_id ' || p_org_id);
        MO_GLOBAL.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        FND_REQUEST.SET_ORG_ID (p_org_id);
        DBMS_APPLICATION_INFO.set_client_info (p_org_id);

        ln_request_id   :=
            fnd_request.submit_request (application   => gc_appl_shrt_name,
                                        program       => gc_program_shrt_name,
                                        description   => NULL,
                                        start_time    => NULL,
                                        sub_request   => FALSE,
                                        argument1     => NULL,
                                        argument2     => gc_standard_type,
                                        argument3     => NULL,
                                        argument4     => gc_update_create,
                                        argument5     => NULL,
                                        argument6     => gc_approved,
                                        argument7     => NULL,
                                        argument8     => p_batch_id,
                                        argument9     => p_org_id,
                                        argument10    => NULL,
                                        argument11    => NULL,
                                        argument12    => NULL,
                                        argument13    => NULL);



        COMMIT;

        IF ln_request_id = 0
        THEN
            write_log ('Seeded Open PO import program POXPOPDOI failed ');
        ELSE
            -- wait for request to complete.
            lc_openpo_hdr_dev_phase   := NULL;
            lc_openpo_hdr_phase       := NULL;

            LOOP
                lb_openpo_hdr_req_wait   :=
                    FND_CONCURRENT.WAIT_FOR_REQUEST (
                        request_id   => ln_request_id,
                        interval     => 1,
                        max_wait     => 1,
                        phase        => lc_openpo_hdr_phase,
                        status       => lc_openpo_hdr_status,
                        dev_phase    => lc_openpo_hdr_dev_phase,
                        dev_status   => lc_openpo_hdr_dev_status,
                        MESSAGE      => lc_openpo_hdr_message);

                IF ((UPPER (lc_openpo_hdr_dev_phase) = 'COMPLETE') OR (UPPER (lc_openpo_hdr_phase) = 'COMPLETED'))
                THEN
                    lc_submit_openpo   := 'Y';

                    write_log (
                           ' Open PO Import debug: request_id: '
                        || ln_request_id
                        || ', lc_openpo_hdr_dev_phase: '
                        || lc_openpo_hdr_dev_phase
                        || ',lc_openpo_hdr_phase: '
                        || lc_openpo_hdr_phase);

                    EXIT;
                END IF;
            END LOOP;

            p_submit_openpo           := lc_submit_openpo;
        END IF;
    END submit_po_request;

    -- To generate the proces report..
    --

    PROCEDURE print_processing_summary (p_action     IN     VARCHAR2,
                                        x_ret_code      OUT VARCHAR2)
    IS
        ln_process_cnt    NUMBER := 0;
        ln_error_cnt      NUMBER := 0;
        ln_validate_cnt   NUMBER := 0;
        ln_total          NUMBER := 0;
        ln_new_status     NUMBER := 0;
    BEGIN
        x_ret_code   := gn_suc_const;

        ---------------------------------------------------------------
        --Fetch the summary details from the staging table
        ----------------------------------------------------------------
        SELECT COUNT (DECODE (record_status, gc_new_status, gc_new_status)), COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)),
               COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)), COUNT (1)
          INTO ln_new_status, ln_process_cnt, ln_error_cnt, ln_validate_cnt,
                            ln_total
          FROM XXD_PO_HEADERS_STG_T
         WHERE request_id = gn_conc_request_id;

        write_log (
               'Processed  => '
            || ln_process_cnt
            || ' Error      => '
            || ln_error_cnt
            || ' Total      => '
            || ln_total);
        fnd_file.put_line (
            fnd_file.output,
            '*************************************************************************************');
        fnd_file.put_line (
            fnd_file.output,
            '************************Summary Report***********************************************');
        fnd_file.put_line (
            fnd_file.output,
            '*************************************************************************************');

        IF p_action = gc_extract_only
        THEN
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Header Records Extracted              : '
                || ln_new_status);
        ELSE
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Records processed              : '
                || ln_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Records Successfully Processed : '
                || ln_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Records In Error               : '
                || ln_error_cnt);
        END IF;

        ----------------------------------------------------------------
        SELECT COUNT (DECODE (record_status, gc_new_status, gc_new_status)), COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)),
               COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)), COUNT (1)
          INTO ln_new_status, ln_process_cnt, ln_error_cnt, ln_validate_cnt,
                            ln_total
          FROM XXD_PO_LINES_STG_T
         WHERE request_id = gn_conc_request_id;

        ------------------PO lines------------------------

        --      fnd_file.put_line (fnd_file.output
        --                        ,'*************************************************************************************');
        IF p_action = gc_extract_only
        THEN
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Records Extracted              : '
                || ln_new_status);
        ELSE
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Records processed              : '
                || ln_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Records Successfully Processed : '
                || ln_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Records In Error               : '
                || ln_error_cnt);
        END IF;

        ----------------------------------------------------------------
        SELECT COUNT (DECODE (record_status, gc_new_status, gc_new_status)), COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)),
               COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)), COUNT (1)
          INTO ln_new_status, ln_process_cnt, ln_error_cnt, ln_validate_cnt,
                            ln_total
          FROM XXD_PO_LINE_LOCATIONS_STG_T
         WHERE request_id = gn_conc_request_id;

        -------------------------------PO Line Locations-------------------------------------------

        --      fnd_file.put_line (fnd_file.output
        --                        ,'*************************************************************************************');
        IF p_action = gc_extract_only
        THEN
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Location Records Extracted              : '
                || ln_new_status);
        ELSE
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Line Location Records processed                       : '
                || ln_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of  Line Location Records Successfully Processed : '
                || ln_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of  Line Location Records In Error                           : '
                || ln_error_cnt);
        END IF;

        ----------------------------------------------------------------
        SELECT COUNT (DECODE (record_status, gc_new_status, gc_new_status)), COUNT (DECODE (record_status, gc_process_status, gc_process_status)), COUNT (DECODE (record_status, gc_error_status, gc_error_status)),
               COUNT (DECODE (record_status, gc_validate_status, gc_validate_status)), COUNT (1)
          INTO ln_new_status, ln_process_cnt, ln_error_cnt, ln_validate_cnt,
                            ln_total
          FROM XXD_PO_DISTRIBUTIONS_STG_T
         WHERE request_id = gn_conc_request_id;

        -----------------------PO Distributions-----------------------------------------------------------

        --      fnd_file.put_line (fnd_file.output
        --                        ,'*************************************************************************************');
        IF p_action = gc_extract_only
        THEN
            fnd_file.put_line (fnd_file.output, '  ');
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Distributions Records Extracted              : '
                || ln_new_status);
        ELSE
            fnd_file.put_line (fnd_file.output, '  ');
            --            fnd_file.put_line (fnd_file.output, 'Total number of Distributions Records in New Status              : '
            --                          || ln_new_status);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Distributions Records processed                      : '
                || ln_total);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Distributions Records Successfully Processed : '
                || ln_process_cnt);
            fnd_file.put_line (
                fnd_file.output,
                   'Total number of Distributions Records In Error                          : '
                || ln_error_cnt);
        END IF;

        fnd_file.put_line (
            fnd_file.output,
            '***************************************************************************************');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (
            fnd_file.output,                          --   RPAD ('Object Name'
               --                                  ,50
               --                                  ,' '
               --                                  )
               --                          || '  '
               --                          ||
               RPAD ('USEFUL_INFO1', 50, ' ')
            || '  '
            || RPAD ('USEFUL_INFO2', 50, ' ')
            || '  '
            || RPAD ('USEFUL_INFO3', 50, ' ')
            || '  '
            || RPAD ('USEFUL_INFO4', 50, ' ')
            || '  '
            || RPAD ('Error Message', 500, ' '));
        fnd_file.put_line (
            fnd_file.output,                                  --    RPAD ('--'
               --                                  ,50
               --                                  ,'-'
               --                                  )
               --                          || '  '
               --                          ||
               RPAD ('--', 50, '-')
            || '  '
            || RPAD ('--', 50, '-')
            || '  '
            || RPAD ('--', 50, '-')
            || '  '
            || RPAD ('--', 50, '-')
            || '  '
            || RPAD ('--', 500, '-'));

        FOR error_in IN (SELECT OBJECT_NAME, ERROR_MESSAGE, USEFUL_INFO1,
                                USEFUL_INFO2, USEFUL_INFO3, USEFUL_INFO4
                           FROM XXD_ERROR_LOG_T
                          WHERE REQUEST_ID = gn_conc_request_id)
        LOOP
            fnd_file.put_line (
                fnd_file.output,              --    RPAD (error_in.OBJECT_NAME
                   --                                     ,50
                   --                                     ,' '
                   --                                     )
                   --                             || '  '
                   --                             ||
                   RPAD (error_in.USEFUL_INFO1, 50, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO2, ' '), 50, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO3, ' '), 50, ' ')
                || '  '
                || RPAD (NVL (error_in.USEFUL_INFO4, ' '), 50, ' ')
                || '  '
                || RPAD (error_in.ERROR_MESSAGE, 500, ' '));
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
            write_log (
                   SUBSTR (SQLERRM, 1, 150)
                || ' Exception in print_processing_summary procedure ');
    END print_processing_summary;

    PROCEDURE transfer_po_distributions (
        p_po_header_id          IN     NUMBER,
        p_po_line_id            IN     NUMBER,
        --p_line_location_id             IN     NUMBER,
        p_interface_header_id   IN     NUMBER,
        p_interface_line_id     IN     NUMBER,
        --p_interface_line_location_id   IN     NUMBER,
        x_ret_code                 OUT VARCHAR2 --    ,x_rec_count                     OUT               NUMBER
                                               --   ,x_int_run_id                    OUT               NUMBER
                                               )
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_distributions_records                                   *
    *                                                                                             *
    * Description          :  This procedure will populate the PO_DISTRIBUTIONS_INTERFACE program *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_distributions_t
            IS TABLE OF PO_DISTRIBUTIONS_INTERFACE%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_distributions_type        type_po_distributions_t;

        ln_valid_rec_cnt                NUMBER := 0;
        ln_count                        NUMBER := 0;
        ln_int_run_id                   NUMBER;
        l_bulk_errors                   NUMBER := 0;
        lx_interface_distributions_id   NUMBER := 0;

        ex_bulk_exceptions              EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception            EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_PO_DISTRIBUTIONS_STG_T XPOD
             WHERE     XPOD.record_status = gc_validate_status
                   AND XPOD.po_header_id = p_po_header_id
                   AND XPOD.po_line_id = p_po_line_id --AND XPOD.line_location_id = p_line_location_id
                                                     ;
    BEGIN
        x_ret_code   := gn_suc_const;
        write_log ('Start of transfer_po_distributions procedure');

        SAVEPOINT INSERT_TABLE3;

        fnd_file.put_line (fnd_file.LOG, 'Test1');

        --fnd_file.put_line (fnd_file.LOG, 'p_po_header_id ' || p_po_header_id);
        --fnd_file.put_line (fnd_file.LOG, 'p_po_line_id  ' || p_po_line_id);

        lt_po_distributions_type.DELETE;

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count           := ln_count + 1;
            ln_valid_rec_cnt   := c_get_valid_rec%ROWCOUNT;
            --
            write_log ('Row count :' || ln_valid_rec_cnt);

            --fnd_file.put_line (fnd_file.LOG, 'Test2');

            BEGIN
                SELECT PO_DISTRIBUTIONS_INTERFACE_S.NEXTVAL
                  INTO lx_interface_distributions_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --  SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --   SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'transfer_po_distributions',
                        NULL,
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_distributions procedure ');
                    write_log (
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_distributions procedure ');
                    RAISE ex_program_exception;
            END;

            ----------------Collect PO line distributions Records from stage table--------------
            lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                p_interface_header_id;
            lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                p_interface_line_id;
            lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_DISTRIBUTION_ID   :=
                lx_interface_distributions_id;
            lt_po_distributions_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                rec_get_valid_rec.PO_HEADER_ID;
            --lt_po_distributions_type(ln_valid_rec_cnt).PO_RELEASE_ID                           :=         rec_get_valid_rec.PO_RELEASE_ID        ;
            --lt_po_distributions_type(ln_valid_rec_cnt).PO_LINE_ID                              :=         rec_get_valid_rec.PO_LINE_ID        ;
            --lt_po_distributions_type(ln_valid_rec_cnt).LINE_LOCATION_ID                        :=         rec_get_valid_rec.LINE_LOCATION_ID        ;
            --lt_po_distributions_type(ln_valid_rec_cnt).PO_DISTRIBUTION_ID                      :=         rec_get_valid_rec.PO_DISTRIBUTION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).DISTRIBUTION_NUM   :=
                rec_get_valid_rec.DISTRIBUTION_NUM;
            --lt_po_distributions_type(ln_valid_rec_cnt).SOURCE_DISTRIBUTION_ID                  :=         rec_get_valid_rec.SOURCE_DISTRIBUTION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).ORG_ID   :=
                rec_get_valid_rec.ORG_ID;
            lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_ORDERED   :=
                rec_get_valid_rec.QUANTITY_ORDERED;
            lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_DELIVERED   :=
                rec_get_valid_rec.QUANTITY_DELIVERED;
            lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_BILLED   :=
                rec_get_valid_rec.QUANTITY_BILLED;
            lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_CANCELLED   :=
                rec_get_valid_rec.QUANTITY_CANCELLED;
            lt_po_distributions_type (ln_valid_rec_cnt).RATE_DATE   :=
                rec_get_valid_rec.RATE_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).RATE   :=
                rec_get_valid_rec.RATE;
            lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_LOCATION   :=
                rec_get_valid_rec.DELIVER_TO_LOCATION;
            --lt_po_distributions_type(ln_valid_rec_cnt).DELIVER_TO_LOCATION_ID                  :=         rec_get_valid_rec.DELIVER_TO_LOCATION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_PERSON_FULL_NAME   :=
                rec_get_valid_rec.DELIVER_TO_PERSON_FULL_NAME;
            --lt_po_distributions_type(ln_valid_rec_cnt).DELIVER_TO_PERSON_ID                    :=         rec_get_valid_rec.DELIVER_TO_PERSON_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_TYPE   :=
                rec_get_valid_rec.DESTINATION_TYPE;
            lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_TYPE_CODE   :=
                rec_get_valid_rec.DESTINATION_TYPE_CODE;
            lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_ORGANIZATION   :=
                rec_get_valid_rec.DESTINATION_ORGANIZATION;
            --lt_po_distributions_type(ln_valid_rec_cnt).DESTINATION_ORGANIZATION_ID             :=         rec_get_valid_rec.DESTINATION_ORGANIZATION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_SUBINVENTORY   :=
                rec_get_valid_rec.DESTINATION_SUBINVENTORY;
            lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_CONTEXT   :=
                rec_get_valid_rec.DESTINATION_CONTEXT;
            lt_po_distributions_type (ln_valid_rec_cnt).SET_OF_BOOKS   :=
                rec_get_valid_rec.SET_OF_BOOKS;
            --lt_po_distributions_type(ln_valid_rec_cnt).SET_OF_BOOKS_ID                         :=         rec_get_valid_rec.SET_OF_BOOKS_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).CHARGE_ACCOUNT   :=
                rec_get_valid_rec.CHARGE_ACCOUNT;
            --lt_po_distributions_type(ln_valid_rec_cnt).CHARGE_ACCOUNT_ID                       :=         rec_get_valid_rec.CHARGE_ACCOUNT_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).BUDGET_ACCOUNT   :=
                rec_get_valid_rec.BUDGET_ACCOUNT;
            --lt_po_distributions_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_ID                       :=         rec_get_valid_rec.BUDGET_ACCOUNT_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).ACCURAL_ACCOUNT   :=
                rec_get_valid_rec.ACCURAL_ACCOUNT;
            --lt_po_distributions_type(ln_valid_rec_cnt).ACCRUAL_ACCOUNT_ID                      :=         rec_get_valid_rec.ACCRUAL_ACCOUNT_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).VARIANCE_ACCOUNT   :=
                rec_get_valid_rec.VARIANCE_ACCOUNT;
            --lt_po_distributions_type(ln_valid_rec_cnt).VARIANCE_ACCOUNT_ID                     :=         rec_get_valid_rec.VARIANCE_ACCOUNT_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).AMOUNT_BILLED   :=
                rec_get_valid_rec.AMOUNT_BILLED;
            lt_po_distributions_type (ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG   :=
                rec_get_valid_rec.ACCRUE_ON_RECEIPT_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).ACCRUED_FLAG   :=
                rec_get_valid_rec.ACCRUED_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).PREVENT_ENCUMBRANCE_FLAG   :=
                rec_get_valid_rec.PREVENT_ENCUMBRANCE_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).ENCUMBERED_FLAG   :=
                rec_get_valid_rec.ENCUMBERED_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).ENCUMBERED_AMOUNT   :=
                rec_get_valid_rec.ENCUMBERED_AMOUNT;
            lt_po_distributions_type (ln_valid_rec_cnt).UNENCUMBERED_QUANTITY   :=
                rec_get_valid_rec.UNENCUMBERED_QUANTITY;
            lt_po_distributions_type (ln_valid_rec_cnt).UNENCUMBERED_AMOUNT   :=
                rec_get_valid_rec.UNENCUMBERED_AMOUNT;
            lt_po_distributions_type (ln_valid_rec_cnt).FAILED_FUNDS   :=
                rec_get_valid_rec.FAILED_FUNDS;
            lt_po_distributions_type (ln_valid_rec_cnt).FAILED_FUNDS_LOOKUP_CODE   :=
                rec_get_valid_rec.FAILED_FUNDS_LOOKUP_CODE;
            lt_po_distributions_type (ln_valid_rec_cnt).GL_ENCUMBERED_DATE   :=
                rec_get_valid_rec.GL_ENCUMBERED_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).GL_ENCUMBERED_PERIOD_NAME   :=
                rec_get_valid_rec.GL_ENCUMBERED_PERIOD_NAME;
            lt_po_distributions_type (ln_valid_rec_cnt).GL_CANCELLED_DATE   :=
                rec_get_valid_rec.GL_CANCELLED_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).GL_CLOSED_DATE   :=
                rec_get_valid_rec.GL_CLOSED_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).REQ_HEADER_REFERENCE_NUM   :=
                rec_get_valid_rec.REQ_HEADER_REFERENCE_NUM;
            lt_po_distributions_type (ln_valid_rec_cnt).REQ_LINE_REFERENCE_NUM   :=
                rec_get_valid_rec.REQ_LINE_REFERENCE_NUM;
            --lt_po_distributions_type(ln_valid_rec_cnt).REQ_DISTRIBUTION_ID                     :=         rec_get_valid_rec.REQ_DISTRIBUTION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_ENTITY   :=
                rec_get_valid_rec.WIP_ENTITY;
            --lt_po_distributions_type(ln_valid_rec_cnt).WIP_ENTITY_ID                           :=         rec_get_valid_rec.WIP_ENTITY_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_OPERATION_SEQ_NUM   :=
                rec_get_valid_rec.WIP_OPERATION_SEQ_NUM;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_RESOURCE_SEQ_NUM   :=
                rec_get_valid_rec.WIP_RESOURCE_SEQ_NUM;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_REPETITIVE_SCHEDULE   :=
                rec_get_valid_rec.WIP_REPETITIVE_SCHEDULE;
            --lt_po_distributions_type(ln_valid_rec_cnt).WIP_REPETITIVE_SCHEDULE_ID              :=         rec_get_valid_rec.WIP_REPETITIVE_SCHEDULE_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_LINE_CODE   :=
                rec_get_valid_rec.WIP_LINE_CODE;
            lt_po_distributions_type (ln_valid_rec_cnt).WIP_LINE_ID   :=
                rec_get_valid_rec.WIP_LINE_ID;
            lt_po_distributions_type (ln_valid_rec_cnt).BOM_RESOURCE_CODE   :=
                rec_get_valid_rec.BOM_RESOURCE_CODE;
            --lt_po_distributions_type(ln_valid_rec_cnt).BOM_RESOURCE_ID                         :=         rec_get_valid_rec.BOM_RESOURCE_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).USSGL_TRANSACTION_CODE   :=
                rec_get_valid_rec.USSGL_TRANSACTION_CODE;
            lt_po_distributions_type (ln_valid_rec_cnt).GOVERNMENT_CONTEXT   :=
                rec_get_valid_rec.GOVERNMENT_CONTEXT;
            lt_po_distributions_type (ln_valid_rec_cnt).PROJECT   :=
                rec_get_valid_rec.PROJECT;
            --lt_po_distributions_type(ln_valid_rec_cnt).PROJECT_ID                              :=         rec_get_valid_rec.PROJECT_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).TASK   :=
                rec_get_valid_rec.TASK;
            --lt_po_distributions_type(ln_valid_rec_cnt).TASK_ID                                 :=         rec_get_valid_rec.TASK_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).END_ITEM_UNIT_NUMBER   :=
                rec_get_valid_rec.END_ITEM_UNIT_NUMBER;
            lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE   :=
                rec_get_valid_rec.EXPENDITURE;
            lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_TYPE   :=
                rec_get_valid_rec.EXPENDITURE_TYPE;
            lt_po_distributions_type (ln_valid_rec_cnt).PROJECT_ACCOUNTING_CONTEXT   :=
                rec_get_valid_rec.PROJECT_ACCOUNTING_CONTEXT;
            lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION   :=
                rec_get_valid_rec.EXPENDITURE_ORGANIZATION;
            --lt_po_distributions_type(ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION_ID             :=         rec_get_valid_rec.EXPENDITURE_ORGANIZATION_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).PROJECT_RELEATED_FLAG   :=
                rec_get_valid_rec.PROJECT_RELEATED_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_ITEM_DATE   :=
                rec_get_valid_rec.EXPENDITURE_ITEM_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                rec_get_valid_rec.ATTRIBUTE_CATEGORY;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                rec_get_valid_rec.ATTRIBUTE1;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                rec_get_valid_rec.ATTRIBUTE2;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                rec_get_valid_rec.ATTRIBUTE3;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                rec_get_valid_rec.ATTRIBUTE4;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                rec_get_valid_rec.ATTRIBUTE5;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                rec_get_valid_rec.ATTRIBUTE6;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                rec_get_valid_rec.ATTRIBUTE7;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                rec_get_valid_rec.ATTRIBUTE8;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                rec_get_valid_rec.ATTRIBUTE9;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                rec_get_valid_rec.ATTRIBUTE10;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                rec_get_valid_rec.ATTRIBUTE11;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                rec_get_valid_rec.ATTRIBUTE12;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                rec_get_valid_rec.ATTRIBUTE13;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                rec_get_valid_rec.ATTRIBUTE14;
            lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                rec_get_valid_rec.ATTRIBUTE15;
            lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                rec_get_valid_rec.LAST_UPDATE_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                rec_get_valid_rec.LAST_UPDATED_BY;
            lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                rec_get_valid_rec.LAST_UPDATE_LOGIN;
            lt_po_distributions_type (ln_valid_rec_cnt).CREATION_DATE   :=
                rec_get_valid_rec.CREATION_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).CREATED_BY   :=
                rec_get_valid_rec.CREATED_BY;
            --lt_po_distributions_type(ln_valid_rec_cnt).REQUEST_ID                              :=         rec_get_valid_rec.REQUEST_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).PROGRAM_APPLICATION_ID   :=
                rec_get_valid_rec.PROGRAM_APPLICATION_ID;
            --lt_po_distributions_type(ln_valid_rec_cnt).PROGRAM_ID                              :=         rec_get_valid_rec.PROGRAM_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).PROGRAM_UPDATE_DATE   :=
                rec_get_valid_rec.PROGRAM_UPDATE_DATE;
            lt_po_distributions_type (ln_valid_rec_cnt).RECOVERABLE_TAX   :=
                rec_get_valid_rec.RECOVERABLE_TAX;
            lt_po_distributions_type (ln_valid_rec_cnt).NONRECOVERABLE_TAX   :=
                rec_get_valid_rec.NONRECOVERABLE_TAX;
            lt_po_distributions_type (ln_valid_rec_cnt).RECOVERY_RATE   :=
                rec_get_valid_rec.RECOVERY_RATE;
            lt_po_distributions_type (ln_valid_rec_cnt).TAX_RECOVERY_OVERRIDE_FLAG   :=
                rec_get_valid_rec.TAX_RECOVERY_OVERRIDE_FLAG;
            --lt_po_distributions_type(ln_valid_rec_cnt).AWARD_ID                                :=         rec_get_valid_rec.AWARD_ID        ;
            --lt_po_distributions_type(ln_valid_rec_cnt).OKE_CONTRACT_LINE_ID                    :=         rec_get_valid_rec.OKE_CONTRACT_LINE_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_LINE_NUM   :=
                rec_get_valid_rec.OKE_CONTRACT_LINE_NUM;
            --lt_po_distributions_type(ln_valid_rec_cnt).OKE_CONTRACT_DELIVERABLE_ID             :=         rec_get_valid_rec.OKE_CONTRACT_DELIVERABLE_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_DELIVERABLE_NUM   :=
                rec_get_valid_rec.OKE_CONTRACT_DELIVERABLE_NUM;
            lt_po_distributions_type (ln_valid_rec_cnt).AWARD_NUMBER   :=
                rec_get_valid_rec.AWARD_NUMBER;
            lt_po_distributions_type (ln_valid_rec_cnt).AMOUNT_ORDERED   :=
                rec_get_valid_rec.AMOUNT_ORDERED;
            lt_po_distributions_type (ln_valid_rec_cnt).INVOICE_ADJUSTMENT_FLAG   :=
                rec_get_valid_rec.INVOICE_ADJUSTMENT_FLAG;
            lt_po_distributions_type (ln_valid_rec_cnt).DEST_CHARGE_ACCOUNT_ID   :=
                rec_get_valid_rec.DEST_CHARGE_ACCOUNT_ID;
            lt_po_distributions_type (ln_valid_rec_cnt).DEST_VARIANCE_ACCOUNT_ID   :=
                rec_get_valid_rec.DEST_VARIANCE_ACCOUNT_ID;
            --lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_LINE_LOCATION_ID :=             p_interface_line_location_id;
            --lt_po_distributions_type(ln_valid_rec_cnt).PROCESSING_ID                           :=         rec_get_valid_rec.PROCESSING_ID        ;
            lt_po_distributions_type (ln_valid_rec_cnt).PROCESS_CODE   :=
                rec_get_valid_rec.PROCESS_CODE;
            lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_DISTRIBUTION_REF   :=
                rec_get_valid_rec.INTERFACE_DISTRIBUTION_REF;
        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the PO_DISTRIBUTIONS_INTERFACE table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_po_distributions_type.COUNT SAVE EXCEPTIONS
            INSERT INTO PO_DISTRIBUTIONS_INTERFACE
                 VALUES lt_po_distributions_type (ln_cnt);

        -------------------------------------------------------------------
        --Update the records that have been transferred to PO_DISTRIBUTIONS_INTERFACE
        --as PROCESSED in staging table
        -------------------------------------------------------------------



        /*         (SELECT INTERFACE_DISTRIBUTION_REF
                    FROM PO_DISTRIBUTIONS_INTERFACE
                   WHERE INTERFACE_DISTRIBUTION_REF = XPOD.PO_DISTRIBUTION_ID); */

        COMMIT;
    --  x_rec_count := ln_valid_rec_cnt;

    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE3;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_distributions',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_distributions procedure ');

                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_distributions procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_distributions',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_distributions procedure');
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_distributions procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_distributions;

    PROCEDURE transfer_po_line_loc_records (
        p_po_header_id          IN     NUMBER,
        p_po_line_id            IN     NUMBER,
        p_interface_header_id   IN     NUMBER,
        p_interface_line_id     IN     NUMBER,
        x_ret_code                 OUT VARCHAR2 --   ,x_rec_count                        OUT                NUMBER
                                               --      ,x_int_run_id                    OUT                NUMBER
                                               )
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_line_loc_records                                        *
    *                                                                                             *
    * Description          :  This procedure will populate the PO_LINE_LOCATIONS_INTERFACE program*
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_line_loc_t
            IS TABLE OF PO_LINE_LOCATIONS_INTERFACE%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_loc_type        type_po_line_loc_t;

        ln_valid_rec_cnt           NUMBER := 0;
        ln_count                   NUMBER := 0;
        ln_int_run_id              NUMBER;
        l_bulk_errors              NUMBER := 0;
        lx_interface_line_loc_id   NUMBER := 0;

        ex_bulk_exceptions         EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception       EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_PO_LINE_LOCATIONS_STG_T XPOL
             WHERE     XPOL.record_status = gc_validate_status
                   AND XPOL.po_header_id = p_po_header_id
                   AND XPOL.po_line_id = p_po_line_id;
    BEGIN
        x_ret_code   := gn_suc_const;
        write_log ('Start of transfer_po_line_loc_records procedure');
        write_log (
               'Start of transfer_po_line_loc_records p_po_header_id => '
            || p_po_header_id);
        write_log (
               'Start of transfer_po_line_loc_records p_po_line_id  => '
            || p_po_line_id);
        SAVEPOINT INSERT_TABLE3;



        lt_po_line_loc_type.DELETE;

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count           := ln_count + 1;
            ln_valid_rec_cnt   := c_get_valid_rec%ROWCOUNT;
            --
            write_log ('Row count :' || ln_valid_rec_cnt);

            BEGIN
                SELECT PO_LINE_LOCATIONS_INTERFACE_S.NEXTVAL
                  INTO lx_interface_line_loc_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --  SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --   SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'transfer_po_line_loc_records',
                        NULL,
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_line_loc_records procedure ');
                    write_log (
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_line_loc_records procedure ');
                    RAISE ex_program_exception;
            END;

            --          INSERT INTO PO_LINE_LOCATIONS_INTERFACE
            --    ( INTERFACE_LINE_LOCATION_ID, INTERFACE_LINE_ID, INTERFACE_HEADER_ID,
            --      destination_type_code, QUANTITY,
            --      CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY )
            --    VALUES
            --    ( PO_LINE_LOCATIONS_INTERFACE_S.NEXTVAL, PO_LINES_INTERFACE_S.CURRVAL, PO_HEADERS_INTERFACE_S.CURRVAL,
            --      'INVENTORY', 10,
            --      SYSDATE, 1, SYSDATE, 1 );
            ----------------Collect PO line location Records from stage table--------------
            lt_po_line_loc_type (ln_valid_rec_cnt).INTERFACE_LINE_LOCATION_ID   :=
                lx_interface_line_loc_id;
            lt_po_line_loc_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                p_interface_header_id;
            lt_po_line_loc_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                p_interface_line_id;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PROCESSING_ID                          :=        rec_get_valid_rec.PROCESSING_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PROCESS_CODE                           :=        rec_get_valid_rec.PROCESS_CODE        ;
            lt_po_line_loc_type (ln_valid_rec_cnt).LINE_LOCATION_ID   :=
                PO_LINE_LOCATIONS_INTERFACE_S.NEXTVAL; --   rec_get_valid_rec.LINE_LOCATION_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).destination_type_code                  :=   'INVENTORY' ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).SHIPMENT_TYPE                          :=        rec_get_valid_rec.SHIPMENT_TYPE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).SHIPMENT_NUM                           :=        rec_get_valid_rec.SHIPMENT_NUM        ;
            lt_po_line_loc_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                rec_get_valid_rec.SHIP_TO_ORGANIZATION_ID;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_CODE              :=        rec_get_valid_rec.SHIP_TO_ORGANIZATION_CODE        ;
            lt_po_line_loc_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                rec_get_valid_rec.SHIP_TO_LOCATION_ID;
            --lt_po_line_loc_type(ln_valid_rec_cnt).SHIP_TO_LOCATION                       :=        'Goleta Head Quater';--rec_get_valid_rec.SHIP_TO_LOCATION        ;
            --lt_po_line_loc_type(ln_valid_rec_cnt).TERMS_ID                             :=        rec_get_valid_rec.TERMS_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PAYMENT_TERMS                          :=        rec_get_valid_rec.PAYMENT_TERMS        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).QTY_RCV_EXCEPTION_CODE                 :=        rec_get_valid_rec.QTY_RCV_EXCEPTION_CODE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).FREIGHT_CARRIER                        :=        rec_get_valid_rec.FREIGHT_CARRIER        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).FOB                                    :=        rec_get_valid_rec.FOB        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).FREIGHT_TERMS                          :=        rec_get_valid_rec.FREIGHT_TERMS        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE          :=        rec_get_valid_rec.ENFORCE_SHIP_TO_LOCATION_CODE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG         :=        rec_get_valid_rec.ALLOW_SUBSTITUTE_RECEIPTS_FLAG        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED             :=        rec_get_valid_rec.DAYS_EARLY_RECEIPT_ALLOWED        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED              :=        rec_get_valid_rec.DAYS_LATE_RECEIPT_ALLOWED        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE            :=        rec_get_valid_rec.RECEIPT_DAYS_EXCEPTION_CODE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).INVOICE_CLOSE_TOLERANCE                :=        rec_get_valid_rec.INVOICE_CLOSE_TOLERANCE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).RECEIVE_CLOSE_TOLERANCE                :=        rec_get_valid_rec.RECEIVE_CLOSE_TOLERANCE        ;
            --        --lt_po_line_loc_type(ln_valid_rec_cnt).RECEIVING_ROUTING_ID                 :=        rec_get_valid_rec.RECEIVING_ROUTING_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).RECEIVING_ROUTING                      :=        rec_get_valid_rec.RECEIVING_ROUTING        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG                 :=        rec_get_valid_rec.ACCRUE_ON_RECEIPT_FLAG        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).FIRM_FLAG                              :=        rec_get_valid_rec.FIRM_FLAG        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).NEED_BY_DATE                           :=      sysdate;--  rec_get_valid_rec.NEED_BY_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PROMISED_DATE                          :=      sysdate;--  rec_get_valid_rec.PROMISED_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).FROM_LINE_LOCATION_ID                  :=        rec_get_valid_rec.FROM_LINE_LOCATION_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).INSPECTION_REQUIRED_FLAG               :=        rec_get_valid_rec.INSPECTION_REQUIRED_FLAG        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).RECEIPT_REQUIRED_FLAG                  :=        rec_get_valid_rec.RECEIPT_REQUIRED_FLAG        ;
            --        --lt_po_line_loc_type(ln_valid_rec_cnt).SOURCE_SHIPMENT_ID                   :=        rec_get_valid_rec.SOURCE_SHIPMENT_ID        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).NOTE_TO_RECEIVER                       :=        rec_get_valid_rec.NOTE_TO_RECEIVER        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).TRANSACTION_FLOW_HEADER_ID             :=        rec_get_valid_rec.TRANSACTION_FLOW_HEADER_ID        ;
            lt_po_line_loc_type (ln_valid_rec_cnt).QUANTITY   :=
                rec_get_valid_rec.QUANTITY;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PRICE_DISCOUNT                         :=        rec_get_valid_rec.PRICE_DISCOUNT        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).START_DATE                             :=        rec_get_valid_rec.START_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).END_DATE                               :=        rec_get_valid_rec.END_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).PRICE_OVERRIDE                         :=        rec_get_valid_rec.PRICE_OVERRIDE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).LEAD_TIME                              :=        rec_get_valid_rec.LEAD_TIME        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).LEAD_TIME_UNIT                         :=        rec_get_valid_rec.LEAD_TIME_UNIT        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).AMOUNT                                 :=        rec_get_valid_rec.AMOUNT        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).SECONDARY_QUANTITY                     :=        rec_get_valid_rec.SECONDARY_QUANTITY        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).SECONDARY_UNIT_OF_MEASURE              :=        rec_get_valid_rec.SECONDARY_UNIT_OF_MEASURE        ;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                rec_get_valid_rec.ATTRIBUTE_CATEGORY;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                rec_get_valid_rec.ATTRIBUTE1;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                rec_get_valid_rec.ATTRIBUTE2;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                rec_get_valid_rec.ATTRIBUTE3;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                rec_get_valid_rec.ATTRIBUTE4;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                rec_get_valid_rec.ATTRIBUTE5;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                rec_get_valid_rec.ATTRIBUTE6;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                rec_get_valid_rec.ATTRIBUTE7;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                rec_get_valid_rec.ATTRIBUTE8;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                rec_get_valid_rec.ATTRIBUTE9;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                rec_get_valid_rec.ATTRIBUTE10;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                rec_get_valid_rec.ATTRIBUTE11;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                rec_get_valid_rec.ATTRIBUTE12;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                rec_get_valid_rec.ATTRIBUTE13;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                rec_get_valid_rec.ATTRIBUTE14;
            lt_po_line_loc_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                rec_get_valid_rec.ATTRIBUTE15;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).CREATION_DATE                          :=        rec_get_valid_rec.CREATION_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).CREATED_BY                             :=        rec_get_valid_rec.CREATED_BY        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).LAST_UPDATE_DATE                       :=        rec_get_valid_rec.LAST_UPDATE_DATE        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).LAST_UPDATED_BY                        :=        rec_get_valid_rec.LAST_UPDATED_BY        ;
            --        lt_po_line_loc_type(ln_valid_rec_cnt).LAST_UPDATE_LOGIN                      :=        rec_get_valid_rec.LAST_UPDATE_LOGIN        ;
            --lt_po_line_loc_type(ln_valid_rec_cnt).REQUEST_ID                           :=        rec_get_valid_rec.REQUEST_ID        ;
            --lt_po_line_loc_type(ln_valid_rec_cnt).PROGRAM_APPLICATION_ID               :=        rec_get_valid_rec.PROGRAM_APPLICATION_ID        ;
            --lt_po_line_loc_type(ln_valid_rec_cnt).PROGRAM_ID                           :=        rec_get_valid_rec.PROGRAM_ID        ;
            --lt_po_line_loc_type(ln_valid_rec_cnt).PROGRAM_UPDATE_DATE                  :=        rec_get_valid_rec.PROGRAM_UPDATE_DATE        ;
            --Modified for 08-MAY-2015
            lt_po_line_loc_type (ln_valid_rec_cnt).UNIT_OF_MEASURE   :=
                rec_get_valid_rec.UNIT_OF_MEASURE;
        --Modified for 08-MAY-2015
        --        lt_po_line_loc_type(ln_valid_rec_cnt).PAYMENT_TYPE                           :=        rec_get_valid_rec.PAYMENT_TYPE        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).DESCRIPTION                            :=        rec_get_valid_rec.DESCRIPTION        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).WORK_APPROVER_ID                     :=        rec_get_valid_rec.WORK_APPROVER_ID        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).AUCTION_PAYMENT_ID                   :=        rec_get_valid_rec.AUCTION_PAYMENT_ID        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).BID_PAYMENT_ID                       :=        rec_get_valid_rec.BID_PAYMENT_ID        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).PROJECT_ID                           :=        rec_get_valid_rec.PROJECT_ID        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).TASK_ID                              :=        rec_get_valid_rec.TASK_ID        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).AWARD_ID                             :=        rec_get_valid_rec.AWARD_ID        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).EXPENDITURE_TYPE                       :=        rec_get_valid_rec.EXPENDITURE_TYPE        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION_ID          :=        rec_get_valid_rec.EXPENDITURE_ORGANIZATION_ID        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).EXPENDITURE_ITEM_DATE                  :=        rec_get_valid_rec.EXPENDITURE_ITEM_DATE        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).VALUE_BASIS                            :=        rec_get_valid_rec.VALUE_BASIS        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).MATCHING_BASIS                         :=        rec_get_valid_rec.MATCHING_BASIS        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).PREFERRED_GRADE                        :=        rec_get_valid_rec.PREFERRED_GRADE        ;
        --lt_po_line_loc_type(ln_valid_rec_cnt).TAX_CODE_ID                          :=        rec_get_valid_rec.TAX_CODE_ID        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).TAX_NAME                               :=        rec_get_valid_rec.TAX_NAME        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).TAXABLE_FLAG                           :=        rec_get_valid_rec.TAXABLE_FLAG        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).QTY_RCV_TOLERANCE                      :=        rec_get_valid_rec.QTY_RCV_TOLERANCE        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_DELIVERY_PERIOD                    :=        rec_get_valid_rec.CLM_DELIVERY_PERIOD        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_DELIVERY_PERIOD_UOM                :=        rec_get_valid_rec.CLM_DELIVERY_PERIOD_UOM        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_POP_DURATION                       :=        rec_get_valid_rec.CLM_POP_DURATION        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_POP_DURATION_UOM                   :=        rec_get_valid_rec.CLM_POP_DURATION_UOM        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_PROMISE_PERIOD                     :=        rec_get_valid_rec.CLM_PROMISE_PERIOD        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_PROMISE_PERIOD_UOM                 :=        rec_get_valid_rec.CLM_PROMISE_PERIOD_UOM        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_PERIOD_PERF_START_DATE             :=        rec_get_valid_rec.CLM_PERIOD_PERF_START_DATE        ;
        --        lt_po_line_loc_type(ln_valid_rec_cnt).CLM_PERIOD_PERF_END_DATE               :=        rec_get_valid_rec.CLM_PERIOD_PERF_END_DATE        ;
        --


        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the PO_LINE_LOCATIONS_INTERFACE table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_po_line_loc_type.COUNT SAVE EXCEPTIONS
            INSERT INTO PO_LINE_LOCATIONS_INTERFACE
                 VALUES lt_po_line_loc_type (ln_cnt);

        -------------------------------------------------------------------
        --Update the records that have been transferred to PO_LINE_LOCATIONS_INTERFACE
        --as PROCESSED in staging table
        -------------------------------------------------------------------

        UPDATE XXD_PO_LINE_LOCATIONS_STG_T XPOL
           SET XPOL.record_status   = gc_process_status
         WHERE EXISTS
                   (SELECT INTERFACE_LINE_LOCATION_ID
                      FROM PO_LINE_LOCATIONS_INTERFACE
                     WHERE from_line_location_id = XPOL.line_location_id);

        COMMIT;
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE3;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_line_loc_records',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_loc_records procedure ');

                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_loc_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_line_loc_records',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_loc_records procedure');
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_loc_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_line_loc_records;



    PROCEDURE transfer_po_line_records (
        p_po_header_id          IN     NUMBER,
        p_new_po_header_id      IN     NUMBER,
        p_interface_header_id   IN     NUMBER,
        p_header_org_id         IN     NUMBER,
        x_ret_code                 OUT VARCHAR2 --        ,x_rec_count                   OUT              NUMBER
                                               --        ,x_int_run_id                  OUT              NUMBER
                                               )
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_line_records                                            *
    *                                                                                             *
    * Description          :  This procedure will populate the po_lines_interface program         *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_line_t IS TABLE OF po_lines_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_type        type_po_line_t;

        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;
        lx_interface_line_id   NUMBER := 0;

        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception   EXCEPTION;
        l_org_id               NUMBER; --Added by BT Technology Team on 13-May-2015

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_PO_LINES_STG_T XPOL
             WHERE     XPOL.record_status = gc_validate_status
                   AND XPOL.po_header_id = p_po_header_id;

        CURSOR c_get_valid_rec1 (p_po_line_id NUMBER, p_po_header_id NUMBER)
        IS
            SELECT *
              FROM XXD_PO_DISTRIBUTIONS_STG_T XPOD
             WHERE     XPOD.record_status = gc_validate_status
                   AND XPOD.po_header_id = p_po_header_id
                   AND XPOD.po_line_id = p_po_line_id --AND XPOD.line_location_id = p_line_location_id
                                                     ;

        lcu_c_get_valid_rec1   c_get_valid_rec1%ROWTYPE;
    BEGIN
        x_ret_code   := gn_suc_const;
        write_log (
               'Start of transfer_po_line_records procedure =>'
            || p_po_header_id);

        --SAVEPOINT INSERT_TABLE2;

        SELECT COUNT (*)
          INTO ln_count
          FROM XXD_PO_LINES_STG_T XPOL
         WHERE     XPOL.record_status = gc_validate_status
               AND XPOL.po_header_id = p_po_header_id;

        write_log (
               'Start of transfer_po_line_records procedure => ln_count => '
            || ln_count
            || 'in status => '
            || gc_validate_status);
        write_log (
               'Start of transfer_po_line_records procedure => p_new_po_header_id => '
            || p_new_po_header_id
            || 'in status => '
            || gc_validate_status);
        ln_count     := 0;

        lt_po_line_type.DELETE;

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count           := ln_count + 1;
            ln_valid_rec_cnt   := c_get_valid_rec%ROWCOUNT;
            --
            write_log ('Row count :' || ln_valid_rec_cnt);

            BEGIN
                SELECT PO_LINES_INTERFACE_S.NEXTVAL
                  INTO lx_interface_line_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --  SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --   SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'transfer_po_header_records',
                        NULL,
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_line_records procedure ');
                    write_log (
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_po_line_records procedure ');
                    RAISE ex_program_exception;
            END;


            ----------------Collect PO line Records from stage table--------------
            lt_po_line_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                lx_interface_line_id;
            lt_po_line_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                p_interface_header_id;
            lt_po_line_type (ln_valid_rec_cnt).organization_id   :=
                p_header_org_id;
            --        lt_po_line_type(ln_valid_rec_cnt).ACTION                                :=         rec_get_valid_rec.ACTION    ;
            --        lt_po_line_type(ln_valid_rec_cnt).GROUP_CODE                            :=         rec_get_valid_rec.GROUP_CODE    ;
            lt_po_line_type (ln_valid_rec_cnt).LINE_NUM   :=
                rec_get_valid_rec.LINE_NUM;
            --        lt_po_line_type(ln_valid_rec_cnt).PO_LINE_ID                          :=          PO_LINES_S.nextval  ;
            --        lt_po_line_type(ln_valid_rec_cnt).SHIPMENT_NUM                          :=         rec_get_valid_rec.SHIPMENT_NUM    ;
            --lt_po_line_type(ln_valid_rec_cnt).LINE_LOCATION_ID                    :=         rec_get_valid_rec.LINE_LOCATION_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SHIPMENT_TYPE                         :=         rec_get_valid_rec.SHIPMENT_TYPE    ;
            --lt_po_line_type(ln_valid_rec_cnt).REQUISITION_LINE_ID                 :=         rec_get_valid_rec.REQUISITION_LINE_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DOCUMENT_NUM                          :=         rec_get_valid_rec.DOCUMENT_NUM    ;
            --lt_po_line_type(ln_valid_rec_cnt).RELEASE_NUM                         :=         rec_get_valid_rec.RELEASE_NUM    ;
            lt_po_line_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                p_new_po_header_id;                    --PO_HEADERS_S.CURRVAL;
            --lt_po_line_type(ln_valid_rec_cnt).PO_RELEASE_ID                       :=         rec_get_valid_rec.PO_RELEASE_ID    ;
            --lt_po_line_type(ln_valid_rec_cnt).SOURCE_SHIPMENT_ID                  :=         rec_get_valid_rec.SOURCE_SHIPMENT_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CONTRACT_NUM                          :=         rec_get_valid_rec.CONTRACT_NUM    ;
            lt_po_line_type (ln_valid_rec_cnt).LINE_TYPE   :=
                rec_get_valid_rec.LINE_TYPE;
            --lt_po_line_type(ln_valid_rec_cnt).LINE_TYPE_ID                        :=         rec_get_valid_rec.LINE_TYPE_ID    ;
            lt_po_line_type (ln_valid_rec_cnt).ITEM   :=
                rec_get_valid_rec.ITEM;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ID   :=
                rec_get_valid_rec.ITEM_ID;
            --        lt_po_line_type(ln_valid_rec_cnt).ITEM_REVISION                         :=         rec_get_valid_rec.ITEM_REVISION    ;
            --lt_po_line_type(ln_valid_rec_cnt).CATEGORY                              :=         rec_get_valid_rec.CATEGORY    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CATEGORY_ID                         :=         rec_get_valid_rec.CATEGORY_ID    ;
            --       lt_po_line_type(ln_valid_rec_cnt).VENDOR_PRODUCT_NUM                    :=         rec_get_valid_rec.VENDOR_PRODUCT_NUM    ;
            --Modified for 08-MAY-2015
            lt_po_line_type (ln_valid_rec_cnt).UOM_CODE   :=
                rec_get_valid_rec.UOM_CODE;
            --Modified for 08-MAY-2015
            --        lt_po_line_type(ln_valid_rec_cnt).UNIT_OF_MEASURE                       :=         rec_get_valid_rec.UNIT_OF_MEASURE    ;
            lt_po_line_type (ln_valid_rec_cnt).QUANTITY   :=
                rec_get_valid_rec.QUANTITY;
            --        lt_po_line_type(ln_valid_rec_cnt).COMMITTED_AMOUNT                      :=         rec_get_valid_rec.COMMITTED_AMOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).MIN_ORDER_QUANTITY                    :=         rec_get_valid_rec.MIN_ORDER_QUANTITY    ;
            --        lt_po_line_type(ln_valid_rec_cnt).MAX_ORDER_QUANTITY                    :=         rec_get_valid_rec.MAX_ORDER_QUANTITY    ;
            lt_po_line_type (ln_valid_rec_cnt).UNIT_PRICE   :=
                rec_get_valid_rec.UNIT_PRICE;
            --        lt_po_line_type(ln_valid_rec_cnt).LIST_PRICE_PER_UNIT                   :=         rec_get_valid_rec.LIST_PRICE_PER_UNIT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).MARKET_PRICE                          :=         rec_get_valid_rec.MARKET_PRICE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).ALLOW_PRICE_OVERRIDE_FLAG             :=         rec_get_valid_rec.ALLOW_PRICE_OVERRIDE_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).NOT_TO_EXCEED_PRICE                   :=         rec_get_valid_rec.NOT_TO_EXCEED_PRICE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).NEGOTIATED_BY_PREPARER_FLAG           :=         rec_get_valid_rec.NEGOTIATED_BY_PREPARER_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).UN_NUMBER                             :=         rec_get_valid_rec.UN_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).UN_NUMBER_ID                          :=         rec_get_valid_rec.UN_NUMBER_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).HAZARD_CLASS                          :=         rec_get_valid_rec.HAZARD_CLASS    ;
            ---lt_po_line_type(ln_valid_rec_cnt).HAZARD_CLASS_ID                    :=         rec_get_valid_rec.HAZARD_CLASS_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).NOTE_TO_VENDOR                        :=         rec_get_valid_rec.NOTE_TO_VENDOR    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TRANSACTION_REASON_CODE               :=         rec_get_valid_rec.TRANSACTION_REASON_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TAXABLE_FLAG                          :=         rec_get_valid_rec.TAXABLE_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TAX_NAME                              :=         rec_get_valid_rec.TAX_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TYPE_1099                             :=         rec_get_valid_rec.TYPE_1099    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CAPITAL_EXPENSE_FLAG                  :=         rec_get_valid_rec.CAPITAL_EXPENSE_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).INSPECTION_REQUIRED_FLAG              :=         rec_get_valid_rec.INSPECTION_REQUIRED_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECEIPT_REQUIRED_FLAG                 :=         rec_get_valid_rec.RECEIPT_REQUIRED_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PAYMENT_TERMS                         :=         rec_get_valid_rec.PAYMENT_TERMS    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TERMS_ID                              :=         rec_get_valid_rec.TERMS_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_TYPE                            :=         rec_get_valid_rec.PRICE_TYPE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).MIN_RELEASE_AMOUNT                    :=         rec_get_valid_rec.MIN_RELEASE_AMOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_BREAK_LOOKUP_CODE               :=         rec_get_valid_rec.PRICE_BREAK_LOOKUP_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).USSGL_TRANSACTION_CODE                :=         rec_get_valid_rec.USSGL_TRANSACTION_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CLOSED_CODE                           :=         rec_get_valid_rec.CLOSED_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CLOSED_REASON                         :=         rec_get_valid_rec.CLOSED_REASON    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CLOSED_DATE                           :=         rec_get_valid_rec.CLOSED_DATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CLOSED_BY                             :=         rec_get_valid_rec.CLOSED_BY    ;
            --        lt_po_line_type(ln_valid_rec_cnt).INVOICE_CLOSE_TOLERANCE               :=         rec_get_valid_rec.INVOICE_CLOSE_TOLERANCE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECEIVE_CLOSE_TOLERANCE               :=         rec_get_valid_rec.RECEIVE_CLOSE_TOLERANCE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FIRM_FLAG                             :=         rec_get_valid_rec.FIRM_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED            :=         rec_get_valid_rec.DAYS_EARLY_RECEIPT_ALLOWED    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED             :=         rec_get_valid_rec.DAYS_LATE_RECEIPT_ALLOWED    ;
            --        lt_po_line_type(ln_valid_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE         :=         rec_get_valid_rec.ENFORCE_SHIP_TO_LOCATION_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG        :=         rec_get_valid_rec.ALLOW_SUBSTITUTE_RECEIPTS_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECEIVING_ROUTING                     :=         rec_get_valid_rec.RECEIVING_ROUTING    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECEIVING_ROUTING_ID                  :=         rec_get_valid_rec.RECEIVING_ROUTING_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).QTY_RCV_TOLERANCE                     :=         rec_get_valid_rec.QTY_RCV_TOLERANCE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).OVER_TOLERANCE_ERROR_FLAG             :=         rec_get_valid_rec.OVER_TOLERANCE_ERROR_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).QTY_RCV_EXCEPTION_CODE                :=         rec_get_valid_rec.QTY_RCV_EXCEPTION_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE           :=         rec_get_valid_rec.RECEIPT_DAYS_EXCEPTION_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_CODE             :=         rec_get_valid_rec.SHIP_TO_ORGANIZATION_CODE    ;
            lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                rec_get_valid_rec.SHIP_TO_ORGANIZATION_ID;
            --Modified on 08-MAY-2015
            lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                rec_get_valid_rec.SHIP_TO_LOCATION;
            lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                rec_get_valid_rec.SHIP_TO_LOCATION_ID;
            --Modified on 08-MAY-2015
            lt_po_line_type (ln_valid_rec_cnt).NEED_BY_DATE   :=
                rec_get_valid_rec.NEED_BY_DATE;
            lt_po_line_type (ln_valid_rec_cnt).PROMISED_DATE   :=
                rec_get_valid_rec.PROMISED_DATE;
            --        lt_po_line_type(ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG                :=         rec_get_valid_rec.ACCRUE_ON_RECEIPT_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LEAD_TIME                             :=         rec_get_valid_rec.LEAD_TIME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LEAD_TIME_UNIT                        :=         rec_get_valid_rec.LEAD_TIME_UNIT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_DISCOUNT                        :=         rec_get_valid_rec.PRICE_DISCOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FREIGHT_CARRIER                       :=         rec_get_valid_rec.FREIGHT_CARRIER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FOB                                   :=         rec_get_valid_rec.FOB    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FREIGHT_TERMS                         :=         rec_get_valid_rec.FREIGHT_TERMS    ;
            --        lt_po_line_type(ln_valid_rec_cnt).EFFECTIVE_DATE                        :=         rec_get_valid_rec.EFFECTIVE_DATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).EXPIRATION_DATE                       :=         rec_get_valid_rec.EXPIRATION_DATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FROM_HEADER_ID                        :=         rec_get_valid_rec.FROM_HEADER_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FROM_LINE_ID                          :=         rec_get_valid_rec.FROM_LINE_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FROM_LINE_LOCATION_ID                 :=         rec_get_valid_rec.FROM_LINE_LOCATION_ID    ;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE_CATEGORY_LINES   :=
                'PO Data Elements'; --  rec_get_valid_rec.LINE_ATTRIBUTE_CATEGORY_LINES    ;

            -----------------Start of Modification on 13-May-2016-------------
            BEGIN
                SELECT organization_id
                  INTO l_org_id
                  FROM hr_operating_units
                 WHERE name = 'Deckers Japan OU';

                IF l_org_id = p_header_org_id
                THEN
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE_CATEGORY_LINES   :=
                        'Intercompany PO Copy';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Org ID not present for this Operating Unit');
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Org ID not present for this Operating Unit');
            END;

            -----------------End of Modification on 13-May-2016-------------
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE1   :=
                rec_get_valid_rec.LINE_ATTRIBUTE1;
            fnd_file.put_line (fnd_file.LOG, 'After LINE_ATTRIBUTE1');
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE2   :=
                rec_get_valid_rec.LINE_ATTRIBUTE2;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE3   :=
                rec_get_valid_rec.LINE_ATTRIBUTE3;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE4   :=
                rec_get_valid_rec.LINE_ATTRIBUTE4;
            fnd_file.put_line (fnd_file.LOG, 'After LINE_ATTRIBUTE4');

            --Modified on 13-MAY-2015
            IF l_org_id = p_header_org_id
            THEN
                lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE5   := NULL;
            ELSE
                lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE5   :=
                    rec_get_valid_rec.LINE_ATTRIBUTE5;
            END IF;

            --Modified on 13-MAY-2015
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE6   :=
                rec_get_valid_rec.LINE_ATTRIBUTE6;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE7   :=
                rec_get_valid_rec.LINE_ATTRIBUTE7;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE8   :=
                rec_get_valid_rec.LINE_ATTRIBUTE8;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE9   :=
                rec_get_valid_rec.LINE_ATTRIBUTE9;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE10   :=
                rec_get_valid_rec.LINE_ATTRIBUTE10;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE11   :=
                rec_get_valid_rec.LINE_ATTRIBUTE11;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE12   :=
                rec_get_valid_rec.LINE_ATTRIBUTE12;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE13   :=
                rec_get_valid_rec.LINE_ATTRIBUTE13;
            fnd_file.put_line (fnd_file.LOG, 'After LINE_ATTRIBUTE13');
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE14   :=
                rec_get_valid_rec.FROM_HEADER_ID;
            lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE15   :=
                rec_get_valid_rec.FROM_LINE_ID;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE_CATEGORY   :=
                'PO Line Locations Elements'; --rec_get_valid_rec.SHIPMENT_ATTRIBUTE_CATEGORY    ;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE1   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE1;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE2   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE2;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE3   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE3;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE4   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE4;
            /*lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE4 :=
               TO_CHAR (rec_get_valid_rec.SHIPMENT_ATTRIBUTE4,
                        'YYYY/MM/DD HH12:MI:SS');
           fnd_file.put_line(fnd_file.log,'SHIPMENT_ATTRIBUTE4 '|| TO_CHAR (rec_get_valid_rec.SHIPMENT_ATTRIBUTE4,
                        'YYYY/MM/DD HH12:MI:SS')); */

            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE5   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE5;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE6   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE6;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE7   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE7;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE8   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE8;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE9   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE9;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE10   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE10;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE11   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE11;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE12   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE12;
            fnd_file.put_line (fnd_file.LOG, 'After SHIPMENT_ATTRIBUTE12');
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE13   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE13;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE14   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE14;
            lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE15   :=
                rec_get_valid_rec.SHIPMENT_ATTRIBUTE15;
            --        lt_po_line_type(ln_valid_rec_cnt).LAST_UPDATE_DATE                      :=         rec_get_valid_rec.LAST_UPDATE_DATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LAST_UPDATED_BY                       :=         rec_get_valid_rec.LAST_UPDATED_BY    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LAST_UPDATE_LOGIN                     :=         rec_get_valid_rec.LAST_UPDATE_LOGIN    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CREATION_DATE                         :=         rec_get_valid_rec.CREATION_DATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CREATED_BY                            :=         rec_get_valid_rec.CREATED_BY    ;
            --lt_po_line_type(ln_valid_rec_cnt).REQUEST_ID                          :=         rec_get_valid_rec.REQUEST_ID    ;
            --lt_po_line_type(ln_valid_rec_cnt).PROGRAM_APPLICATION_ID              :=         rec_get_valid_rec.PROGRAM_APPLICATION_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PROGRAM_ID                            :=         rec_get_valid_rec.PROGRAM_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PROGRAM_UPDATE_DATE                   :=         rec_get_valid_rec.PROGRAM_UPDATE_DATE    ;
            --lt_po_line_type(ln_valid_rec_cnt).ORGANIZATION_ID                     :=         rec_get_valid_rec.ORGANIZATION_ID    ;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE_CATEGORY   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE_CATEGORY;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE1   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE1;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE2   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE2;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE3   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE3;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE4   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE4;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE5   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE5;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE6   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE6;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE7   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE7;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE8   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE8;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE9   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE9;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE10   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE10;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE11   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE11;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE12   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE12;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE13   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE13;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE14   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE14;
            lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE15   :=
                rec_get_valid_rec.ITEM_ATTRIBUTE15;
            lt_po_line_type (ln_valid_rec_cnt).taxable_flag   :=
                'N';

            --Modified for 08-MAY-2015
            lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION   :=
                rec_get_valid_rec.ITEM_DESCRIPTION;

            --Modified for 08-MAY-2015

            --        lt_po_line_type(ln_valid_rec_cnt).UNIT_WEIGHT                           :=         rec_get_valid_rec.UNIT_WEIGHT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).WEIGHT_UOM_CODE                       :=         rec_get_valid_rec.WEIGHT_UOM_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).VOLUME_UOM_CODE                       :=         rec_get_valid_rec.VOLUME_UOM_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).UNIT_VOLUME                           :=         rec_get_valid_rec.UNIT_VOLUME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TEMPLATE_ID                           :=         rec_get_valid_rec.TEMPLATE_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TEMPLATE_NAME                         :=         rec_get_valid_rec.TEMPLATE_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LINE_REFERENCE_NUM                    :=         rec_get_valid_rec.LINE_REFERENCE_NUM    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SOURCING_RULE_NAME                    :=         rec_get_valid_rec.SOURCING_RULE_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TAX_STATUS_INDICATOR                  :=         rec_get_valid_rec.TAX_STATUS_INDICATOR    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PROCESS_CODE                          :=         rec_get_valid_rec.PROCESS_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_CHG_ACCEPT_FLAG                 :=         rec_get_valid_rec.PRICE_CHG_ACCEPT_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_BREAK_FLAG                      :=         rec_get_valid_rec.PRICE_BREAK_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PRICE_UPDATE_TOLERANCE                :=         rec_get_valid_rec.PRICE_UPDATE_TOLERANCE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TAX_USER_OVERRIDE_FLAG                :=         rec_get_valid_rec.TAX_USER_OVERRIDE_FLAG    ;
            --lt_po_line_type(ln_valid_rec_cnt).TAX_CODE_ID                         :=         rec_get_valid_rec.TAX_CODE_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).NOTE_TO_RECEIVER                      :=         rec_get_valid_rec.NOTE_TO_RECEIVER    ;
            --lt_po_line_type(ln_valid_rec_cnt).OKE_CONTRACT_HEADER_ID              :=         rec_get_valid_rec.OKE_CONTRACT_HEADER_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).OKE_CONTRACT_HEADER_NUM               :=         rec_get_valid_rec.OKE_CONTRACT_HEADER_NUM    ;
            --        lt_po_line_type(ln_valid_rec_cnt).OKE_CONTRACT_VERSION_ID               :=         rec_get_valid_rec.OKE_CONTRACT_VERSION_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SECONDARY_UNIT_OF_MEASURE             :=         rec_get_valid_rec.SECONDARY_UNIT_OF_MEASURE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SECONDARY_UOM_CODE                    :=         rec_get_valid_rec.SECONDARY_UOM_CODE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SECONDARY_QUANTITY                    :=         rec_get_valid_rec.SECONDARY_QUANTITY    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PREFERRED_GRADE                       :=         rec_get_valid_rec.PREFERRED_GRADE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).VMI_FLAG                              :=         rec_get_valid_rec.VMI_FLAG    ;
            --lt_po_line_type(ln_valid_rec_cnt).AUCTION_HEADER_ID                   :=         rec_get_valid_rec.AUCTION_HEADER_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).AUCTION_LINE_NUMBER                   :=         rec_get_valid_rec.AUCTION_LINE_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).AUCTION_DISPLAY_NUMBER                :=         rec_get_valid_rec.AUCTION_DISPLAY_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).BID_NUMBER                            :=         rec_get_valid_rec.BID_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).BID_LINE_NUMBER                       :=         rec_get_valid_rec.BID_LINE_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).ORIG_FROM_REQ_FLAG                    :=         rec_get_valid_rec.ORIG_FROM_REQ_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CONSIGNED_FLAG                        :=         rec_get_valid_rec.CONSIGNED_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SUPPLIER_REF_NUMBER                   :=         rec_get_valid_rec.SUPPLIER_REF_NUMBER    ;
            --lt_po_line_type(ln_valid_rec_cnt).CONTRACT_ID                         :=         rec_get_valid_rec.CONTRACT_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).JOB_ID                                :=         rec_get_valid_rec.JOB_ID    ;
            ----        lt_po_line_type(ln_valid_rec_cnt).AMOUNT                                :=         rec_get_valid_rec.AMOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).JOB_NAME                              :=         rec_get_valid_rec.JOB_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CONTRACTOR_FIRST_NAME                 :=         rec_get_valid_rec.CONTRACTOR_FIRST_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CONTRACTOR_LAST_NAME                  :=         rec_get_valid_rec.CONTRACTOR_LAST_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DROP_SHIP_FLAG                        :=         rec_get_valid_rec.DROP_SHIP_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).BASE_UNIT_PRICE                       :=         rec_get_valid_rec.BASE_UNIT_PRICE    ;
            --lt_po_line_type(ln_valid_rec_cnt).TRANSACTION_FLOW_HEADER_ID          :=         rec_get_valid_rec.TRANSACTION_FLOW_HEADER_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).JOB_BUSINESS_GROUP_ID                 :=         rec_get_valid_rec.JOB_BUSINESS_GROUP_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).JOB_BUSINESS_GROUP_NAME               :=         rec_get_valid_rec.JOB_BUSINESS_GROUP_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).CATALOG_NAME                          :=         rec_get_valid_rec.CATALOG_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SUPPLIER_PART_AUXID                   :=         rec_get_valid_rec.SUPPLIER_PART_AUXID    ;
            --lt_po_line_type(ln_valid_rec_cnt).IP_CATEGORY_ID                      :=         rec_get_valid_rec.IP_CATEGORY_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).TRACKING_QUANTITY_IND                 :=         rec_get_valid_rec.TRACKING_QUANTITY_IND    ;
            --        lt_po_line_type(ln_valid_rec_cnt).SECONDARY_DEFAULT_IND                 :=         rec_get_valid_rec.SECONDARY_DEFAULT_IND    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DUAL_UOM_DEVIATION_HIGH               :=         rec_get_valid_rec.DUAL_UOM_DEVIATION_HIGH    ;
            --        lt_po_line_type(ln_valid_rec_cnt).DUAL_UOM_DEVIATION_LOW                :=         rec_get_valid_rec.DUAL_UOM_DEVIATION_LOW    ;
            --lt_po_line_type(ln_valid_rec_cnt).PROCESSING_ID                       :=         rec_get_valid_rec.PROCESSING_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).LINE_LOC_POPULATED_FLAG               :=         rec_get_valid_rec.LINE_LOC_POPULATED_FLAG    ;
            --        lt_po_line_type(ln_valid_rec_cnt).IP_CATEGORY_NAME                      :=         rec_get_valid_rec.IP_CATEGORY_NAME    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RETAINAGE_RATE                        :=         rec_get_valid_rec.RETAINAGE_RATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).MAX_RETAINAGE_AMOUNT                  :=         rec_get_valid_rec.MAX_RETAINAGE_AMOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PROGRESS_PAYMENT_RATE                 :=         rec_get_valid_rec.PROGRESS_PAYMENT_RATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).RECOUPMENT_RATE                       :=         rec_get_valid_rec.RECOUPMENT_RATE    ;
            --        lt_po_line_type(ln_valid_rec_cnt).ADVANCE_AMOUNT                        :=         rec_get_valid_rec.ADVANCE_AMOUNT    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FILE_LINE_NUMBER                      :=         rec_get_valid_rec.FILE_LINE_NUMBER    ;
            --        lt_po_line_type(ln_valid_rec_cnt).PARENT_INTERFACE_LINE_ID            :=         rec_get_valid_rec.PARENT_INTERFACE_LINE_ID    ;
            --        lt_po_line_type(ln_valid_rec_cnt).FILE_LINE_LANGUAGE                    :=         rec_get_valid_rec.FILE_LINE_LANGUAGE    ;

            OPEN c_get_valid_rec1 (rec_get_valid_rec.po_line_id,
                                   rec_get_valid_rec.po_header_id);

            --fnd_file.put_line(fnd_file.log,'rec_get_valid_rec.po_header_id '||rec_get_valid_rec.po_header_id);
            --fnd_file.put_line(fnd_file.log,'rec_get_valid_rec.po_line_id '||rec_get_valid_rec.po_line_id);
            --fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.DESTINATION_SUBINVENTORY '||lcu_c_get_valid_rec1.DESTINATION_SUBINVENTORY);

            FETCH c_get_valid_rec1 INTO lcu_c_get_valid_rec1;

            --fnd_file.put_line(fnd_file.log,'Before INSERT into PO_DISTRIBUTIONS_INTERFACE');

            /*    fnd_file.put_line(fnd_file.log,'p_interface_header_id '|| p_interface_header_id);
                fnd_file.put_line(fnd_file.log,'lx_interface_line_id '|| lx_interface_line_id);
               -- fnd_file.put_line(fnd_file.log,'PO_DISTRIBUTIONS_INTERFACE_S.NEXTVAL ',
              --  fnd_file.put_line(fnd_file.log,'PO_HEADERS_S.CURRVAL ',
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.DISTRIBUTION_NUM '||lcu_c_get_valid_rec1.DISTRIBUTION_NUM);
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.ORG_ID '||lcu_c_get_valid_rec1.ORG_ID);
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.DESTINATION_SUBINVENTORY '||lcu_c_get_valid_rec1.DESTINATION_SUBINVENTORY);
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.QUANTITY_ORDERED '||lcu_c_get_valid_rec1.QUANTITY_ORDERED );
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.QUANTITY_DELIVERED '||lcu_c_get_valid_rec1.QUANTITY_DELIVERED);
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.QUANTITY_BILLED '||lcu_c_get_valid_rec1.QUANTITY_BILLED );
                fnd_file.put_line(fnd_file.log,'lcu_c_get_valid_rec1.QUANTITY_CANCELLED '||lcu_c_get_valid_rec1.QUANTITY_CANCELLED);*/

            INSERT INTO PO_DISTRIBUTIONS_INTERFACE (
                            INTERFACE_HEADER_ID,
                            INTERFACE_LINE_ID,
                            INTERFACE_DISTRIBUTION_ID,
                            PO_HEADER_ID,
                            DISTRIBUTION_NUM,
                            ORG_ID,
                            DESTINATION_SUBINVENTORY,
                            QUANTITY_ORDERED,
                            QUANTITY_DELIVERED,
                            QUANTITY_BILLED,
                            QUANTITY_CANCELLED)
                     VALUES (p_interface_header_id,
                             lx_interface_line_id,
                             PO_DISTRIBUTIONS_INTERFACE_S.NEXTVAL,
                             p_new_po_header_id,       --PO_HEADERS_S.CURRVAL,
                             lcu_c_get_valid_rec1.DISTRIBUTION_NUM,
                             lcu_c_get_valid_rec1.ORG_ID,
                             lcu_c_get_valid_rec1.DESTINATION_SUBINVENTORY,
                             --lcu_c_get_valid_rec1.QUANTITY_ORDERED,
                             rec_get_valid_rec.QUANTITY, --Modified on 14-MAY-2015
                             lcu_c_get_valid_rec1.QUANTITY_DELIVERED,
                             lcu_c_get_valid_rec1.QUANTITY_BILLED,
                             lcu_c_get_valid_rec1.QUANTITY_CANCELLED);

            --fnd_file.put_line (fnd_file.LOG,                            'After INSERT into PO_DISTRIBUTIONS_INTERFACE');
            CLOSE c_get_valid_rec1;
        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the po_lines_interface table for the batch
        ----------------------------------------------------------------
        fnd_file.put_line (
            fnd_file.LOG,
            'Before INSERT into po_lines_interface ' || lt_po_line_type.COUNT);

        --fnd_file.put_line(fnd_file.log,'lt_po_line_type(ln_valid_rec_cnt).SHIP_TO_LOCATION ==>' ||lt_po_line_type(ln_valid_rec_cnt).SHIP_TO_LOCATION);         --            :=         rec_get_valid_rec.SHIP_TO_LOCATION    ;
        --fnd_file.put_line(fnd_file.log,'lt_po_line_type(ln_valid_rec_cnt).SHIP_TO_LOCATION_ID ==>'||lt_po_line_type(ln_valid_rec_cnt).SHIP_TO_LOCATION_ID);      --          :=         rec_get_valid_rec.SHIP_TO_LOCATION_ID    ;
        --fnd_file.put_line(fnd_file.log,'lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION ==>'||lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION);      --    :=        rec_get_valid_rec.ITEM_DESCRIPTION;
        --fnd_file.put_line(fnd_file.log,' lt_po_line_type(ln_valid_rec_cnt).UOM_CODE ==>'||lt_po_line_type(ln_valid_rec_cnt).UOM_CODE);   --                        :=         rec_get_valid_rec.UOM_CODE    ;
        FORALL ln_cnt IN 1 .. lt_po_line_type.COUNT SAVE EXCEPTIONS
            INSERT INTO po_lines_interface
                 VALUES lt_po_line_type (ln_cnt);

        fnd_file.put_line (fnd_file.LOG,
                           'After INSERT into po_lines_interface');

        COMMIT;

        fnd_file.put_line (fnd_file.LOG,
                           'After COMMIT of INSERT into po_lines_interface');

        /*   FOR line_rec in 1 .. lt_po_line_type.count LOOP
             --transfer_po_line_loc_records

         fnd_file.put_line(fnd_file.log,'LINE_ATTRIBUTE14 1 '|| lt_po_line_type(line_rec).LINE_ATTRIBUTE14);
         fnd_file.put_line(fnd_file.log,'LINE_ATTRIBUTE15 1 '||lt_po_line_type(line_rec).LINE_ATTRIBUTE15);
         fnd_file.put_line(fnd_file.log,'INTERFACE_HEADER_ID '||lt_po_line_type(line_rec).INTERFACE_HEADER_ID);
         fnd_file.put_line(fnd_file.log,'INTERFACE_LINE_ID '||lt_po_line_type(line_rec).INTERFACE_LINE_ID);

          --transfer_po_line_loc_records
         transfer_po_distributions( p_po_header_id                      =>          lt_po_line_type(line_rec).LINE_ATTRIBUTE14
                                          ,p_po_line_id                        =>          lt_po_line_type(line_rec).LINE_ATTRIBUTE15
                                          ,p_interface_header_id               =>          lt_po_line_type(line_rec).INTERFACE_HEADER_ID
                                          ,p_interface_line_id                 =>          lt_po_line_type(line_rec).INTERFACE_LINE_ID
                                          ,x_ret_code                          =>          x_ret_code
                                      --  ,x_rec_count                        OUT          NUMBER
                                      --  ,x_int_run_id                       OUT          NUMBER
                                                                               );

               END LOOP; */

        BEGIN
            UPDATE XXD_PO_DISTRIBUTIONS_STG_T XPOD
               SET XPOD.record_status   = gc_process_status
             WHERE     PO_HEADER_ID = p_po_header_id
                   AND EXISTS
                           (SELECT PO_HEADER_ID
                              FROM PO_DISTRIBUTIONS_INTERFACE
                             WHERE PO_HEADER_ID = XPOD.PO_HEADER_ID);
        --fnd_file.put_line(fnd_file.log,'After UPDATE of XXD_PO_DISTRIBUTIONS_STG_T');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'In Exception UPDATE of XXD_PO_DISTRIBUTIONS_STG_T -'
                    || SQLERRM);
        END;

        -------------------------------------------------------------------
        --Update the records that have been transferred to po_lines_interface
        --as PROCESSED in staging table
        -------------------------------------------------------------------
        BEGIN
            UPDATE XXD_PO_LINES_STG_T XPOL
               SET XPOL.record_status   = gc_process_status
             WHERE     PO_HEADER_ID = p_po_header_id
                   AND PO_HEADER_ID IN
                           (SELECT TO_NUMBER (pol.LINE_ATTRIBUTE14)
                              FROM PO_LINES_INTERFACE pol, po_headers_interface poh
                             WHERE     pol.po_header_id = poh.po_header_id
                                   AND poh.vendor_name <>
                                       'On-Hand Conversion'
                                   AND TO_CHAR (pol.LINE_ATTRIBUTE14) =
                                       TO_CHAR (XPOL.PO_HEADER_ID));

            /*  (SELECT 1
                 FROM po_lines_interface pol,po_headers_interface poh
                WHERE pol.po_header_id =poh.po_header_id
                  AND poh.vendor_name <> 'On-Hand Conversion'
                  AND to_char(pol.LINE_ATTRIBUTE14) = to_char(XPOL.FROM_HEADER_ID)   --Added to_char for Invalid Number Exception on 26-may-2015
                  AND to_char(pol.LINE_ATTRIBUTE15) = to_char(XPOL.FROM_LINE_ID));    --Added to_char for Invalid Number Exception on 26-may-2015*/

            fnd_file.put_line (fnd_file.LOG,
                               'After UPDATE of XXD_PO_LINES_STG_T ');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Exception UPDATE of XXD_PO_LINES_STG_T -' || SQLERRM);
        END;
    --        UPDATE XXD_PO_LINE_LOCATIONS_STG_T XPOL
    --        SET    XPOL.record_status        =  gc_process_status
    --        WHERE  EXISTS   (SELECT 1
    --                         FROM   po_lines_interface
    --                         WHERE  LINE_ATTRIBUTE14 = XPOL.po_header_id
    --                           AND LINE_ATTRIBUTE15 = XPOL.po_line_id );


    -- x_rec_count := ln_valid_rec_cnt;
    --fnd_file.put_line(fnd_file.log,'After  UPDATE of XXD_PO_LINES_STG_T ');

    EXCEPTION
        WHEN ex_program_Exception
        THEN
            --ROLLBACK TO INSERT_TABLE2;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            --ROLLBACK TO INSERT_TABLE2;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_line_records',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure ');

                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_po_line_records procedure');
            END LOOP;
        WHEN OTHERS
        THEN
            --         ROLLBACK TO INSERT_TABLE2;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_line_records',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure');
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_po_line_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_line_records;

    PROCEDURE transfer_po_header_records (p_batch_id   IN     NUMBER,
                                          x_ret_code      OUT VARCHAR2 --                                          ,x_rec_count     OUT  NUMBER
                                                                      --                                          ,x_int_run_id    OUT  NUMBER
                                                                      )
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_po_header_records                                          *
    *                                                                                             *
    * Description          :  This procedure will populate the po_headers_interface program       *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to interface table                  *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_header_t IS TABLE OF po_headers_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_headre_type        type_po_header_t;

        ln_valid_rec_cnt         NUMBER := 0;
        ln_count                 NUMBER := 0;
        ln_int_run_id            NUMBER;
        l_bulk_errors            NUMBER := 0;
        lx_interface_header_id   NUMBER := 0;
        l_legder_id              NUMBER;
        l_func_currency          VARCHAR2 (100);
        lc_new_po_header_id      NUMBER := 0;

        ex_bulk_exceptions       EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);

        ex_program_exception     EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec IS
            SELECT *
              FROM XXD_PO_HEADERS_STG_T XPOH
             WHERE     XPOH.record_status IN (gc_validate_status) --, gc_error_status)
                   AND XPOH.batch_id = p_batch_id;
    --and XPOH.po_header_id = 367133;
    BEGIN
        x_ret_code   := gn_suc_const;
        write_log ('Start of transfer_records procedure');

        --SAVEPOINT INSERT_TABLE;

        lt_po_headre_type.DELETE;

        FOR rec_get_valid_rec IN c_get_valid_rec
        LOOP
            ln_count           := ln_count + 1;
            ln_valid_rec_cnt   := c_get_valid_rec%ROWCOUNT;
            --
            write_log ('Row count :' || ln_valid_rec_cnt);

            BEGIN
                SELECT po_headers_interface_s.NEXTVAL
                  INTO lx_interface_header_id
                  FROM DUAL;

                SELECT PO_HEADERS_S.NEXTVAL
                  INTO lc_new_po_header_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    xxd_common_utils.record_error (
                        'PO',
                        gn_org_id,
                        'XXD Open Purchase Orders Conversion Program',
                        --  SQLCODE,
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --   SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'transfer_po_header_records',
                        NULL,
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_records procedure ');
                    write_log (
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_records procedure ');
                    RAISE ex_program_exception;
            END;


            ----------------Collect PO header Records from stage table--------------
            lt_po_headre_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                lx_interface_header_id; --rec_get_valid_rec.INTERFACE_HEADER_ID    ;
            lt_po_headre_type (ln_valid_rec_cnt).BATCH_ID   :=
                rec_get_valid_rec.BATCH_ID;
            --lt_po_headre_type(ln_valid_rec_cnt).INTERFACE_SOURCE_CODE                   :=        rec_get_valid_rec.INTERFACE_SOURCE_CODE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).PROCESS_CODE                              :=        rec_get_valid_rec.PROCESS_CODE    ;
            lt_po_headre_type (ln_valid_rec_cnt).ACTION   :=
                rec_get_valid_rec.ACTION;
            --lt_po_headre_type(ln_valid_rec_cnt).GROUP_CODE                              :=        rec_get_valid_rec.GROUP_CODE    ;
            lt_po_headre_type (ln_valid_rec_cnt).ORG_ID   :=
                rec_get_valid_rec.ORGS_ID;
            lt_po_headre_type (ln_valid_rec_cnt).DOCUMENT_TYPE_CODE   :=
                rec_get_valid_rec.DOCUMENT_SUBTYPE;
            --lt_po_headre_type(ln_valid_rec_cnt).DOCUMENT_SUBTYPE                          :=        rec_get_valid_rec.DOCUMENT_SUBTYPE    ;
            lt_po_headre_type (ln_valid_rec_cnt).DOCUMENT_NUM   :=
                rec_get_valid_rec.DOCUMENT_NUM;
            lt_po_headre_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                lc_new_po_header_id;


            --lt_po_headre_type(ln_valid_rec_cnt).RELEASE_NUM                             :=        rec_get_valid_rec.RELEASE_NUM    ;
            --lt_po_headre_type(ln_valid_rec_cnt).PO_RELEASE_ID                           :=        rec_get_valid_rec.PO_RELEASE_ID    ;
            --lt_po_headre_type(ln_valid_rec_cnt).RELEASE_DATE                            :=        rec_get_valid_rec.RELEASE_DATE    ;
            lt_po_headre_type (ln_valid_rec_cnt).CURRENCY_CODE   :=
                rec_get_valid_rec.CURRENCY_CODE;

            --            lt_po_headre_type(ln_valid_rec_cnt).RATE_TYPE                                 :=        rec_get_valid_rec.RATE_TYPE    ;
            ------------------Hardcode RATE_TYPE to USER in case PO Currency is not equal to functional currency ------------------------
            BEGIN
                SELECT SET_OF_BOOKS_ID
                  INTO l_legder_id
                  FROM hr_operating_units
                 WHERE organization_id = rec_get_valid_rec.ORGS_ID; --lt_po_headre_type (ln_valid_rec_cnt).ORG_ID;


                SELECT currency_code
                  INTO l_func_currency
                  FROM gl_ledgers
                 WHERE     ledger_id = l_legder_id
                       AND ledger_category_code = 'PRIMARY';

                fnd_file.put_line (
                    fnd_file.LOG,
                    ' rec_get_valid_rec.CURRENCY_CODE :' || rec_get_valid_rec.CURRENCY_CODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_func_currency :' || l_func_currency);

                IF l_func_currency <> rec_get_valid_rec.CURRENCY_CODE
                THEN
                    lt_po_headre_type (ln_valid_rec_cnt).RATE_TYPE   :=
                        'User';
                    lt_po_headre_type (ln_valid_rec_cnt).RATE   :=
                        rec_get_valid_rec.RATE;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'lt_po_headre_type(ln_valid_rec_cnt).RATE_TYPE :'
                    || lt_po_headre_type (ln_valid_rec_cnt).RATE_TYPE);
            END;

            ----------------------------------------------------
            --            lt_po_headre_type(ln_valid_rec_cnt).RATE_TYPE_CODE                            :=        rec_get_valid_rec.RATE_TYPE_CODE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).RATE_DATE                                 :=        rec_get_valid_rec.RATE_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).RATE                                      :=        rec_get_valid_rec.RATE    ;
            --lt_po_headre_type (ln_valid_rec_cnt).AGENT_NAME := 'Stewart, Celene'; --rec_get_valid_rec.AGENT_NAME    ;
            --Modified on 13-MAY-2015
            --lt_po_headre_type (ln_valid_rec_cnt).AGENT_NAME := rec_get_valid_rec.AGENT_NAME    ;
            lt_po_headre_type (ln_valid_rec_cnt).AGENT_ID   :=
                rec_get_valid_rec.AGENT_ID;
            --Modified on 13-MAY-2015
            lt_po_headre_type (ln_valid_rec_cnt).VENDOR_NAME   :=
                rec_get_valid_rec.VENDOR_NAME;
            --lt_po_headre_type(ln_valid_rec_cnt).VENDOR_ID                               :=        rec_get_valid_rec.VENDOR_ID    ;
            lt_po_headre_type (ln_valid_rec_cnt).VENDOR_SITE_CODE   :=
                rec_get_valid_rec.VENDOR_SITE_CODE;
            --lt_po_headre_type(ln_valid_rec_cnt).VENDOR_SITE_ID                          :=        rec_get_valid_rec.VENDOR_SITE_ID    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).VENDOR_CONTACT                            :=        rec_get_valid_rec.VENDOR_CONTACT    ;
            --lt_po_headre_type(ln_valid_rec_cnt).VENDOR_CONTACT_ID                       :=        rec_get_valid_rec.VENDOR_CONTACT_ID    ;
            --lt_po_headre_type (ln_valid_rec_cnt).SHIP_TO_LOCATION :=             rec_get_valid_rec.SHIP_TO_LOCATION; Srinivas
            lt_po_headre_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                rec_get_valid_rec.SHIP_TO_LOCATION_ID;
            --lt_po_headre_type (ln_valid_rec_cnt).BILL_TO_LOCATION :=             rec_get_valid_rec.BILL_TO_LOCATION;   ---Srinivas
            lt_po_headre_type (ln_valid_rec_cnt).BILL_TO_LOCATION_ID   :=
                rec_get_valid_rec.BILL_TO_LOCATION_ID;
            --            lt_po_headre_type(ln_valid_rec_cnt).PAYMENT_TERMS                             :=        rec_get_valid_rec.PAYMENT_TERMS    ;
            --lt_po_headre_type(ln_valid_rec_cnt).TERMS_ID                                :=        rec_get_valid_rec.TERMS_ID    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FREIGHT_CARRIER                           :=        rec_get_valid_rec.FREIGHT_CARRIER    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FOB                                       :=        rec_get_valid_rec.FOB    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FREIGHT_TERMS                             :=        rec_get_valid_rec.FREIGHT_TERMS    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).APPROVAL_STATUS                           :=        rec_get_valid_rec.APPROVAL_STATUS    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).APPROVED_DATE                             :=        rec_get_valid_rec.APPROVED_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).REVISED_DATE                              :=        rec_get_valid_rec.REVISED_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).REVISION_NUM                              :=        rec_get_valid_rec.REVISION_NUM    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).NOTE_TO_VENDOR                            :=        rec_get_valid_rec.NOTE_TO_VENDOR    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).NOTE_TO_RECEIVER                          :=        rec_get_valid_rec.NOTE_TO_RECEIVER    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).CONFIRMING_ORDER_FLAG                     :=        rec_get_valid_rec.CONFIRMING_ORDER_FLAG    ;
            lt_po_headre_type (ln_valid_rec_cnt).COMMENTS   :=
                rec_get_valid_rec.COMMENTS;
            --            lt_po_headre_type(ln_valid_rec_cnt).ACCEPTANCE_REQUIRED_FLAG                  :=        rec_get_valid_rec.ACCEPTANCE_REQUIRED_FLAG    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).ACCEPTANCE_DUE_DATE                       :=        rec_get_valid_rec.ACCEPTANCE_DUE_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).AMOUNT_AGREED                             :=        rec_get_valid_rec.AMOUNT_AGREED    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).AMOUNT_LIMIT                              :=        rec_get_valid_rec.AMOUNT_LIMIT    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).MIN_RELEASE_AMOUNT                        :=        rec_get_valid_rec.MIN_RELEASE_AMOUNT    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).EFFECTIVE_DATE                            :=        rec_get_valid_rec.EFFECTIVE_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).EXPIRATION_DATE                           :=        rec_get_valid_rec.EXPIRATION_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).PRINT_COUNT                               :=        rec_get_valid_rec.PRINT_COUNT    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).PRINTED_DATE                              :=        rec_get_valid_rec.PRINTED_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FIRM_FLAG                                 :=        rec_get_valid_rec.FIRM_FLAG    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FROZEN_FLAG                               :=        rec_get_valid_rec.FROZEN_FLAG    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).CLOSED_CODE                               :=        rec_get_valid_rec.CLOSED_CODE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).CLOSED_DATE                               :=        rec_get_valid_rec.CLOSED_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).REPLY_DATE                                :=        rec_get_valid_rec.REPLY_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).REPLY_METHOD                              :=        rec_get_valid_rec.REPLY_METHOD    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).RFQ_CLOSE_DATE                            :=        rec_get_valid_rec.RFQ_CLOSE_DATE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).QUOTE_WARNING_DELAY                       :=        rec_get_valid_rec.QUOTE_WARNING_DELAY    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).VENDOR_DOC_NUM                            :=        rec_get_valid_rec.VENDOR_DOC_NUM    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).APPROVAL_REQUIRED_FLAG                    :=        rec_get_valid_rec.APPROVAL_REQUIRED_FLAG    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).VENDOR_LIST                               :=        rec_get_valid_rec.VENDOR_LIST    ;
            --lt_po_headre_type(ln_valid_rec_cnt).VENDOR_LIST_HEADER_ID                   :=        rec_get_valid_rec.VENDOR_LIST_HEADER_ID    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FROM_HEADER_ID                            :=        rec_get_valid_rec.FROM_HEADER_ID    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).FROM_TYPE_LOOKUP_CODE                     :=        rec_get_valid_rec.FROM_TYPE_LOOKUP_CODE    ;
            --            lt_po_headre_type(ln_valid_rec_cnt).USSGL_TRANSACTION_CODE                    :=        rec_get_valid_rec.USSGL_TRANSACTION_CODE    ;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                'PO Data Elements'; -- rec_get_valid_rec.ATTRIBUTE_CATEGORY    ;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                rec_get_valid_rec.ATTRIBUTE1;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                rec_get_valid_rec.ATTRIBUTE2;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                rec_get_valid_rec.ATTRIBUTE3;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                rec_get_valid_rec.ATTRIBUTE4;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                rec_get_valid_rec.ATTRIBUTE5;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                rec_get_valid_rec.ATTRIBUTE6;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                rec_get_valid_rec.ATTRIBUTE7;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                rec_get_valid_rec.ATTRIBUTE8;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                rec_get_valid_rec.ATTRIBUTE9;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                rec_get_valid_rec.ATTRIBUTE10;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                rec_get_valid_rec.ATTRIBUTE11;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                rec_get_valid_rec.ATTRIBUTE12;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                rec_get_valid_rec.ATTRIBUTE13;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                rec_get_valid_rec.ATTRIBUTE14;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                rec_get_valid_rec.ATTRIBUTE15;
            lt_po_headre_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                rec_get_valid_rec.FROM_HEADER_ID;
            lt_po_headre_type (ln_valid_rec_cnt).CREATION_DATE   :=
                rec_get_valid_rec.CREATION_DATE; --Uncommented by BT Technology Team on 05-May-2015 to get Creation Date of 1206
        --            lt_po_headre_type(ln_valid_rec_cnt).CREATED_BY                                :=        rec_get_valid_rec.CREATED_BY    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).LAST_UPDATE_DATE                          :=        rec_get_valid_rec.LAST_UPDATE_DATE    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).LAST_UPDATED_BY                           :=        rec_get_valid_rec.LAST_UPDATED_BY    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).LAST_UPDATE_LOGIN                         :=        rec_get_valid_rec.LAST_UPDATE_LOGIN    ;
        --            --lt_po_headre_type(ln_valid_rec_cnt).REQUEST_ID                              :=        rec_get_valid_rec.REQUEST_ID    ;
        --lt_po_headre_type(ln_valid_rec_cnt).PROGRAM_APPLICATION_ID                  :=        rec_get_valid_rec.PROGRAM_APPLICATION_ID    ;
        --lt_po_headre_type(ln_valid_rec_cnt).PROGRAM_ID                              :=        rec_get_valid_rec.PROGRAM_ID    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).PROGRAM_UPDATE_DATE                       :=        rec_get_valid_rec.PROGRAM_UPDATE_DATE    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).REFERENCE_NUM                             :=        rec_get_valid_rec.REFERENCE_NUM    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).LOAD_SOURCING_RULES_FLAG                  :=        rec_get_valid_rec.LOAD_SOURCING_RULES_FLAG    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).VENDOR_NUM                                :=        rec_get_valid_rec.VENDOR_NUM    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).FROM_RFQ_NUM                              :=        rec_get_valid_rec.FROM_RFQ_NUM    ;
        --lt_po_headre_type(ln_valid_rec_cnt).WF_GROUP_ID                             :=        rec_get_valid_rec.WF_GROUP_ID    ;
        --lt_po_headre_type(ln_valid_rec_cnt).PCARD_ID                                :=        rec_get_valid_rec.PCARD_ID    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).PAY_ON_CODE                               :=        rec_get_valid_rec.PAY_ON_CODE    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).GLOBAL_AGREEMENT_FLAG                     :=        rec_get_valid_rec.GLOBAL_AGREEMENT_FLAG    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).CONSUME_REQ_DEMAND_FLAG                   :=        rec_get_valid_rec.CONSUME_REQ_DEMAND_FLAG    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).SHIPPING_CONTROL                          :=        rec_get_valid_rec.SHIPPING_CONTROL    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).ENCUMBRANCE_REQUIRED_FLAG                 :=        rec_get_valid_rec.ENCUMBRANCE_REQUIRED_FLAG    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).AMOUNT_TO_ENCUMBER                        :=        rec_get_valid_rec.AMOUNT_TO_ENCUMBER    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).CHANGE_SUMMARY                            :=        rec_get_valid_rec.CHANGE_SUMMARY    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT1                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT1    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT2                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT2    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT3                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT3    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT4                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT4    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT5                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT5    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT6                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT6    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT7                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT7    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT8                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT8    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT9                   :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT9    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT10                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT10    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT11                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT11    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT12                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT12    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT13                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT13    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT14                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT14    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT15                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT15    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT16                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT16    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT17                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT17    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT18                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT18    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT19                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT19    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT20                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT20    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT21                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT21    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT22                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT22    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT23                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT23    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT24                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT24    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT25                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT25    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT26                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT26    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT27                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT27    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT28                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT28    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT29                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT29    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT30                  :=        rec_get_valid_rec.BUDGET_ACCOUNT_SEGMENT30    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT                            :=        rec_get_valid_rec.BUDGET_ACCOUNT    ;
        --lt_po_headre_type(ln_valid_rec_cnt).BUDGET_ACCOUNT_ID                       :=        rec_get_valid_rec.BUDGET_ACCOUNT_ID    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).GL_ENCUMBERED_DATE                        :=        rec_get_valid_rec.GL_ENCUMBERED_DATE    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).GL_ENCUMBERED_PERIOD_NAME                 :=        rec_get_valid_rec.GL_ENCUMBERED_PERIOD_NAME    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).CREATED_LANGUAGE                          :=        rec_get_valid_rec.CREATED_LANGUAGE    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).CPA_REFERENCE                             :=        rec_get_valid_rec.CPA_REFERENCE    ;
        --lt_po_headre_type(ln_valid_rec_cnt).DRAFT_ID                                :=        rec_get_valid_rec.DRAFT_ID    ;
        --lt_po_headre_type(ln_valid_rec_cnt).PROCESSING_ID                           :=        rec_get_valid_rec.PROCESSING_ID    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).PROCESSING_ROUND_NUM                      :=        rec_get_valid_rec.PROCESSING_ROUND_NUM    ;
        --            lt_po_headre_type(ln_valid_rec_cnt).ORIGINAL_PO_HEADER_ID                     :=        rec_get_valid_rec.ORIGINAL_PO_HEADER_ID    ;
        --lt_po_headre_type(ln_valid_rec_cnt).STYLE_ID                                :=        rec_get_valid_rec.STYLE_ID    ;
        -- lt_po_headre_type(ln_valid_rec_cnt).STYLE_DISPLAY_NAME                        :=        rec_get_valid_rec.STYLE_DISPLAY_NAME    ;

        END LOOP;

        -------------------------------------------------------------------
        -- do a bulk insert into the po_headers_interface table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_po_headre_type.COUNT SAVE EXCEPTIONS
            INSERT INTO po_headers_interface
                 VALUES lt_po_headre_type (ln_cnt);

        COMMIT;

        FOR po_header_rec IN 1 .. lt_po_headre_type.COUNT
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'po_header_id 2 '
                || lt_po_headre_type (po_header_rec).po_header_id);


            fnd_file.put_line (
                fnd_file.LOG,
                   'INTERFACE_HEADER_ID '
                || lt_po_headre_type (po_header_rec).INTERFACE_HEADER_ID);
            fnd_file.put_line (
                fnd_file.LOG,
                   'ATTRIBUTE15 old p_po_header_id => '
                || lt_po_headre_type (po_header_rec).ATTRIBUTE15);

            transfer_po_line_records (
                p_po_header_id    =>
                    lt_po_headre_type (po_header_rec).ATTRIBUTE15,
                p_new_po_header_id   =>
                    lt_po_headre_type (po_header_rec).po_header_id,
                p_interface_header_id   =>
                    lt_po_headre_type (po_header_rec).INTERFACE_HEADER_ID,
                p_header_org_id   => lt_po_headre_type (po_header_rec).ORG_ID,
                x_ret_code        => x_ret_code -- ,x_rec_count                     OUT               NUMBER
                                               --,x_int_run_id                     OUT               NUMBER
                                               );
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'test1');

        -------------------------------------------------------------------
        --Update the records that have been transferred to po_headers_interface
        --as PROCESSED in staging table
        -------------------------------------------------------------------

        UPDATE XXD_PO_HEADERS_STG_T XPOH
           SET XPOH.record_status   = gc_process_status
         WHERE     1 = 1
               AND XPOH.batch_id = p_batch_id
               AND EXISTS
                       (SELECT ATTRIBUTE15
                          FROM po_headers_interface
                         WHERE ATTRIBUTE15 = XPOH.PO_HEADER_ID);

        --x_rec_count := ln_valid_rec_cnt;

        fnd_file.put_line (fnd_file.LOG, 'test2');
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            --ROLLBACK TO INSERT_TABLE;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            --ROLLBACK TO INSERT_TABLE;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --  SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'transfer_po_header_records',
                    NULL,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');

                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            --ROLLBACK TO INSERT_TABLE;
            x_ret_code   := gn_err_const;
            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'transfer_po_header_records',
                NULL,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_po_header_records;

    --truncte_stage_tables

    PROCEDURE truncte_stage_tables (x_ret_code OUT VARCHAR2, x_return_mesg OUT VARCHAR2, p_scenario IN VARCHAR2) --Added on 26-June-2015
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        x_ret_code   := gn_suc_const;
        write_log ('Working on truncte_stage_tables to purge the data');

        --Start of changes by BT Technology Team on 26-Jun-2015 --
        DELETE FROM
            XXD_CONV.XXD_PO_LINES_STG_T lines
              WHERE EXISTS
                        (SELECT 1
                           FROM XXD_CONV.XXD_PO_HEADERS_STG_T hdr
                          WHERE     lines.PO_HEADER_ID = hdr.PO_HEADER_ID
                                AND hdr.SCENARIO = p_scenario);

        DELETE FROM
            XXD_CONV.XXD_PO_LINE_LOCATIONS_STG_T loc
              WHERE EXISTS
                        (SELECT 1
                           FROM XXD_CONV.XXD_PO_HEADERS_STG_T hdr
                          WHERE     loc.PO_HEADER_ID = hdr.PO_HEADER_ID
                                AND hdr.SCENARIO = p_scenario);

        DELETE FROM
            XXD_CONV.XXD_PO_DISTRIBUTIONS_STG_T dist
              WHERE EXISTS
                        (SELECT 1
                           FROM XXD_CONV.XXD_PO_HEADERS_STG_T hdr
                          WHERE     dist.PO_HEADER_ID = hdr.PO_HEADER_ID
                                AND hdr.SCENARIO = p_scenario);

        --End of changes by BT Technology Team on 26-Jun-2015 --


        --   EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_PO_HEADERS_STG_T';        --Commented by BT Technology Team on 26-Jun-2015
        DELETE FROM XXD_CONV.XXD_PO_HEADERS_STG_T
              WHERE SCENARIO = p_scenario; --Added by BT Technology Team on 26-Jun-2015

        --   EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_PO_LINES_STG_T';         --Commented by BT Technology Team on 26-Jun-2015

        --  EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_PO_LINE_LOCATIONS_STG_T';  --Commented by BT Technology Team on 26-Jun-2015

        --   EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_PO_DISTRIBUTIONS_STG_T';   --Commented by BT Technology Team on 26-Jun-2015

        Write_log ('Truncate Stage Table Complete');

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            Write_log ('Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --  SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --   SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE extract_po_headers (x_ret_code         OUT VARCHAR2,
                                  x_rec_count        OUT NUMBER,
                                  p_org_name      IN     VARCHAR2,
                                  p_scenario      IN     VARCHAR2,
                                  x_return_mesg      OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a      04-JUL-2014     BT Technology Team     Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_header_t IS TABLE OF XXD_PO_HEADERS_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_header_type      type_po_header_t;
        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception   EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_header_rec (p_1206_org_id NUMBER)
        IS
            SELECT *
              -- FROM XXD_PO_HEADERS_CONV_V a
              FROM xxd_po_headers_conv_1206 a --Replaced extract view with dump tables on 19-May-2015
             WHERE     1 = 1
                   AND scenario = NVL (p_scenario, scenario)
                   --AND po_header_id = 268013
                   --   AND  PO_NUMBER in ('100')--('1054','1056')--('1048')
                   AND org_id = p_1206_org_id               --and rownum <= 50
 --AND TRUNC(CREATION_DATE) >= '01-JAN-2014'  --Added by BT Technology on 30-Apr-2015 for PATCH Instance Testing only (to be removed after Testing)
 --AND NVL (closed_code, 'OPEN') NOT IN ('CLOSED', 'FINALLY CLOSED')  --Added by BT Technology on 30-Apr-2015 for PATCH Instance Testing only (to be removed after Testing)
                                                            --AND ROWNUM < 131
    ; --Added by BT Technology on 30-Apr-2015 for PATCH Instance Testing only (to be removed after Testing)

                                                    --           WHERE  EXISTS
                                                     --              (SELECT 1
                                        --                 FROM ap_suppliers s
                         --                WHERE s.SEGMENT1 = a.vendor_number)
                                           --       AND OU_NAME = 'Deckers US'



        TYPE lt_header_typ IS TABLE OF c_get_header_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;


        lt_po_header_data      lt_header_typ;
    BEGIN
        x_ret_code    := gn_suc_const;
        write_log ('Start of transfer_records procedure');

        lt_po_header_type.DELETE;

        FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
        LOOP
            OPEN c_get_header_rec (TO_NUMBER (lc_org.lookup_code));

            LOOP
                SAVEPOINT INSERT_TABLE1;

                FETCH c_get_header_rec
                    BULK COLLECT INTO lt_po_header_data
                    LIMIT 5000;

                EXIT WHEN lt_po_header_data.COUNT = 0;

                write_log (
                    'transfer_records Count => ' || lt_po_header_data.COUNT);

                IF lt_po_header_data.COUNT > 0
                THEN
                    write_log (
                        'Assign the valus and bulk insert to stage tables');
                    ln_valid_rec_cnt   := 0;

                    FOR rec_get_valid_rec IN lt_po_header_data.FIRST ..
                                             lt_po_header_data.LAST
                    --  FOR rec_get_valid_rec IN c_get_header_rec
                    LOOP
                        ln_count           := ln_count + 1;
                        ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                        --
                        --write_log ('Row count :' || ln_valid_rec_cnt);
                        lt_po_header_type (ln_valid_rec_cnt).RECORD_STATUS   :=
                            gc_new_status;
                        lt_po_header_type (ln_valid_rec_cnt).BATCH_ID   :=
                            NULL;

                        BEGIN
                            SELECT XXD_PO_HEADER_RECORD_ID_S.NEXTVAL
                              INTO lt_po_header_type (ln_valid_rec_cnt).RECORD_ID
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                write_log (
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception fetching group id in transfer_records procedure ');
                                RAISE ex_program_exception;
                        END;

                        lt_po_header_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).INTERFACE_SOURCE_CODE   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PROCESS_CODE   :=
                            'PENDING';
                        lt_po_header_type (ln_valid_rec_cnt).ACTION   :=
                            'ORIGINAL';
                        lt_po_header_type (ln_valid_rec_cnt).GROUP_CODE   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).OU_NAME   :=
                            lt_po_header_data (rec_get_valid_rec).OU_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).ORG_ID   :=
                            lt_po_header_data (rec_get_valid_rec).org_id;
                        lt_po_header_type (ln_valid_rec_cnt).ORGS_ID   :=
                            lt_po_header_data (rec_get_valid_rec).org_id;
                        lt_po_header_type (ln_valid_rec_cnt).PO_NUMBER   :=
                            lt_po_header_data (rec_get_valid_rec).PO_NUMBER;
                        lt_po_header_type (ln_valid_rec_cnt).DOCUMENT_TYPE_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).DOCUMENT_TYPE_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).DOCUMENT_SUBTYPE   :=
                            lt_po_header_data (rec_get_valid_rec).DOCUMENT_SUBTYPE;
                        lt_po_header_type (ln_valid_rec_cnt).DOCUMENT_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).PO_NUMBER;
                        lt_po_header_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                            lt_po_header_data (rec_get_valid_rec).PO_HEADER_ID;
                        lt_po_header_type (ln_valid_rec_cnt).RELEASE_NUM   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PO_RELEASE_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).RELEASE_DATE   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).CURRENCY_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).CURRENCY_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).RATE_TYPE   :=
                            lt_po_header_data (rec_get_valid_rec).RATE_TYPE;
                        lt_po_header_type (ln_valid_rec_cnt).RATE_TYPE_CODE   :=
                            NULL; --  lt_po_header_data (rec_get_valid_rec).RATE_TYPE_CODE    ;
                        lt_po_header_type (ln_valid_rec_cnt).RATE_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).RATE_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).RATE   :=
                            lt_po_header_data (rec_get_valid_rec).RATE;
                        lt_po_header_type (ln_valid_rec_cnt).AGENT_NAME   :=
                            lt_po_header_data (rec_get_valid_rec).AGENT_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).AGENT_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_NAME   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_NUMBER   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_NUMBER;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_SITE_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_SITE_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_SITE_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_CONTACT   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_CONTACT;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_CONTACT_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                            lt_po_header_data (rec_get_valid_rec).SHIP_TO_LOCATION;
                        lt_po_header_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).BILL_TO_LOCATION   :=
                            lt_po_header_data (rec_get_valid_rec).BILL_TO_LOCATION;
                        lt_po_header_type (ln_valid_rec_cnt).BILL_TO_LOCATION_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PAYMENT_TERMS   :=
                            lt_po_header_data (rec_get_valid_rec).TERM_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).TERMS_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).FREIGHT_CARRIER   :=
                            lt_po_header_data (rec_get_valid_rec).FREIGHT_CARRIER;
                        lt_po_header_type (ln_valid_rec_cnt).FOB   :=
                            lt_po_header_data (rec_get_valid_rec).FOB;
                        lt_po_header_type (ln_valid_rec_cnt).FREIGHT_TERMS   :=
                            lt_po_header_data (rec_get_valid_rec).FREIGHT_TERMS_LOOKUP_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).APPROVAL_STATUS   :=
                            lt_po_header_data (rec_get_valid_rec).APPROVAL_STATUS;
                        lt_po_header_type (ln_valid_rec_cnt).APPROVED_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).APPROVED_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).REVISED_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).REVISED_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).REVISION_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).REVISION_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).NOTE_TO_VENDOR   :=
                            lt_po_header_data (rec_get_valid_rec).NOTE_TO_VENDOR;
                        lt_po_header_type (ln_valid_rec_cnt).NOTE_TO_RECEIVER   :=
                            lt_po_header_data (rec_get_valid_rec).NOTE_TO_RECEIVER;
                        lt_po_header_type (ln_valid_rec_cnt).CONFIRMING_ORDER_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).CONFIRMING_ORDER_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).COMMENTS   :=
                            lt_po_header_data (rec_get_valid_rec).COMMENTS;
                        lt_po_header_type (ln_valid_rec_cnt).ACCEPTANCE_REQUIRED_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).ACCEPTANCE_REQUIRED_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).ACCEPTANCE_DUE_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).ACCEPTANCE_DUE_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).AMOUNT_AGREED   :=
                            lt_po_header_data (rec_get_valid_rec).AMOUNT_AGREED;
                        lt_po_header_type (ln_valid_rec_cnt).AMOUNT_LIMIT   :=
                            lt_po_header_data (rec_get_valid_rec).AMOUNT_LIMIT;
                        lt_po_header_type (ln_valid_rec_cnt).MIN_RELEASE_AMOUNT   :=
                            lt_po_header_data (rec_get_valid_rec).MIN_RELEASE_AMOUNT;
                        lt_po_header_type (ln_valid_rec_cnt).EFFECTIVE_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).EFFECTIVE_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).EXPIRATION_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).EXPIRATION_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).PRINT_COUNT   :=
                            lt_po_header_data (rec_get_valid_rec).PRINT_COUNT;
                        lt_po_header_type (ln_valid_rec_cnt).PRINTED_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).PRINTED_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).FIRM_FLAG   :=
                            NULL; --lt_po_header_data (rec_get_valid_rec).FIRM_FLAG    ;
                        lt_po_header_type (ln_valid_rec_cnt).FROZEN_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).FROZEN_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).CLOSED_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).CLOSED_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).CLOSED_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).CLOSED_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).REPLY_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).REPLY_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).REPLY_METHOD   :=
                            lt_po_header_data (rec_get_valid_rec).REPLY_METHOD;
                        lt_po_header_type (ln_valid_rec_cnt).RFQ_CLOSE_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).RFQ_CLOSE_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).QUOTE_WARNING_DELAY   :=
                            lt_po_header_data (rec_get_valid_rec).QUOTE_WARNING_DELAY;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_DOC_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_DOC_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).APPROVAL_REQUIRED_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).APPROVAL_REQUIRED_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_LIST   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_LIST;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_LIST_HEADER_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).FROM_HEADER_ID   :=
                            lt_po_header_data (rec_get_valid_rec).PO_HEADER_ID;
                        lt_po_header_type (ln_valid_rec_cnt).FROM_TYPE_LOOKUP_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).FROM_TYPE_LOOKUP_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).USSGL_TRANSACTION_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).USSGL_TRANSACTION_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE_CATEGORY;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE1;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE2;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE3;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE4;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE5;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE6;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE7;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE8;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE9;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE10;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE11;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE12;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE13;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE14;
                        lt_po_header_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                            lt_po_header_data (rec_get_valid_rec).ATTRIBUTE15;
                        lt_po_header_type (ln_valid_rec_cnt).CREATION_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).CREATION_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).CREATED_BY   :=
                            lt_po_header_data (rec_get_valid_rec).CREATED_BY;
                        lt_po_header_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).LAST_UPDATE_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                            lt_po_header_data (rec_get_valid_rec).LAST_UPDATED_BY;
                        lt_po_header_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                            lt_po_header_data (rec_get_valid_rec).LAST_UPDATE_LOGIN;
                        lt_po_header_type (ln_valid_rec_cnt).REQUEST_ID   :=
                            gn_conc_request_id;
                        lt_po_header_type (ln_valid_rec_cnt).PROGRAM_APPLICATION_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PROGRAM_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PROGRAM_UPDATE_DATE   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).REFERENCE_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).REFERENCE_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).LOAD_SOURCING_RULES_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).LOAD_SOURCING_RULES_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).VENDOR_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).VENDOR_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).FROM_RFQ_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).FROM_RFQ_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).WF_GROUP_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PCARD_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).PAY_ON_CODE   :=
                            lt_po_header_data (rec_get_valid_rec).PAY_ON_CODE;
                        lt_po_header_type (ln_valid_rec_cnt).GLOBAL_AGREEMENT_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).GLOBAL_AGREEMENT_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).CONSUME_REQ_DEMAND_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).CONSUME_REQ_DEMAND_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).SHIPPING_CONTROL   :=
                            lt_po_header_data (rec_get_valid_rec).SHIPPING_CONTROL;
                        lt_po_header_type (ln_valid_rec_cnt).ENCUMBRANCE_REQUIRED_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).ENCUMBRANCE_REQUIRED_FLAG;
                        lt_po_header_type (ln_valid_rec_cnt).AMOUNT_TO_ENCUMBER   :=
                            lt_po_header_data (rec_get_valid_rec).AMOUNT_TO_ENCUMBER;
                        lt_po_header_type (ln_valid_rec_cnt).CHANGE_SUMMARY   :=
                            lt_po_header_data (rec_get_valid_rec).CHANGE_SUMMARY;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT1   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT1;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT2   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT2;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT3   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT3;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT4   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT4;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT5   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT5;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT6   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT6;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT7   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT7;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT8   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT8;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT9   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT9;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT10   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT10;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT11   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT11;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT12   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT12;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT13   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT13;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT14   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT14;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT15   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT15;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT16   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT16;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT17   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT17;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT18   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT18;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT19   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT19;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT20   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT20;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT21   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT21;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT22   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT22;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT23   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT23;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT24   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT24;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT25   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT25;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT26   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT26;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT27   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT27;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT28   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT28;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT29   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT29;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_SEGMENT30   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_SEGMENT30;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT;
                        lt_po_header_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_ID   :=
                            lt_po_header_data (rec_get_valid_rec).BUDGET_ACCOUNT_ID;
                        lt_po_header_type (ln_valid_rec_cnt).GL_ENCUMBERED_DATE   :=
                            lt_po_header_data (rec_get_valid_rec).GL_ENCUMBERED_DATE;
                        lt_po_header_type (ln_valid_rec_cnt).GL_ENCUMBERED_PERIOD_NAME   :=
                            lt_po_header_data (rec_get_valid_rec).GL_ENCUMBERED_PERIOD_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).CREATED_LANGUAGE   :=
                            lt_po_header_data (rec_get_valid_rec).CREATED_LANGUAGE;
                        lt_po_header_type (ln_valid_rec_cnt).CPA_REFERENCE   :=
                            lt_po_header_data (rec_get_valid_rec).CPA_REFERENCE;
                        lt_po_header_type (ln_valid_rec_cnt).DRAFT_ID   :=
                            lt_po_header_data (rec_get_valid_rec).DRAFT_ID;
                        lt_po_header_type (ln_valid_rec_cnt).PROCESSING_ID   :=
                            lt_po_header_data (rec_get_valid_rec).PROCESSING_ID;
                        lt_po_header_type (ln_valid_rec_cnt).PROCESSING_ROUND_NUM   :=
                            lt_po_header_data (rec_get_valid_rec).PROCESSING_ROUND_NUM;
                        lt_po_header_type (ln_valid_rec_cnt).ORIGINAL_PO_HEADER_ID   :=
                            lt_po_header_data (rec_get_valid_rec).ORIGINAL_PO_HEADER_ID;
                        lt_po_header_type (ln_valid_rec_cnt).STYLE_ID   :=
                            NULL;
                        lt_po_header_type (ln_valid_rec_cnt).STYLE_DISPLAY_NAME   :=
                            lt_po_header_data (rec_get_valid_rec).STYLE_DISPLAY_NAME;
                        lt_po_header_type (ln_valid_rec_cnt).SCENARIO   :=
                            lt_po_header_data (rec_get_valid_rec).SCENARIO; --Added Scenario to Stg table 26-Jun-2015
                        lt_po_header_type (ln_valid_rec_cnt).EDI_PROCESSED_FLAG   :=
                            lt_po_header_data (rec_get_valid_rec).EDI_PROCESSED_FLAG; --Added EDI_PROCESSED_FLAG to Stg table 16-Jul-2015
                        lt_po_header_type (ln_valid_rec_cnt).EDI_PROCESSED_STATUS   :=
                            lt_po_header_data (rec_get_valid_rec).EDI_PROCESSED_STATUS; --Added EDI_PROCESSED_STATUS to Stg table 16-Jul-2015
                    END LOOP;

                    -------------------------------------------------------------------
                    -- do a bulk insert into the XXD_PO_HEADERS_STG_T table
                    ----------------------------------------------------------------
                    write_log ('Bulk Insert to XXD_PO_HEADERS_STG_T ');

                    FORALL ln_cnt IN 1 .. lt_po_header_type.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO XXD_PO_HEADERS_STG_T
                             VALUES lt_po_header_type (ln_cnt);
                END IF;

                COMMIT;
            END LOOP;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            END IF;
        END LOOP;


        IF c_get_header_rec%ISOPEN
        THEN
            CLOSE c_get_header_rec;
        END IF;

        x_rec_count   := ln_valid_rec_cnt;
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE1;
            x_ret_code   := gn_err_const;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            END IF;

            write_log ('ex_program_Exception raised' || SQLERRM);
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --    SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --     SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'XXD_PO_HEADERS_STG_T', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE1;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --   SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'XXD_PO_HEADERS_STG_T',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE1;
            x_ret_code   := gn_err_const;
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_header_rec%ISOPEN
            THEN
                CLOSE c_get_header_rec;
            END IF;

            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --   SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'XXD_PO_HEADERS_STG_T',
                NULL,
                'Unexpected Exception while inserting into XXD_PO_LIST_HEADERS_STG_T');
    END extract_po_headers;

    PROCEDURE extract_po_lines (x_ret_code OUT VARCHAR2, x_rec_count OUT NUMBER, x_return_mesg OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a      04-JUL-2014     BT Technology Team     Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_line_t IS TABLE OF XXD_PO_LINES_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_type        type_po_line_t;
        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception   EXCEPTION;
        l_item_desc            VARCHAR2 (240);             --Added 03-Aug-2015

        --------------------------------------------------------
        --Cursor to fetch the  records from header staging table
        ----------------------------------------------------------
        CURSOR c_get_header_rec IS SELECT * FROM XXD_PO_LINES_STG_T;

        --------------------------------------------------------
        --Cursor to fetch the  records from 12.0.3 table
        ----------------------------------------------------------
        /*      CURSOR c_get_line_rec
              IS
                 SELECT xpol.*
                  FROM XXD_PO_LINES_CONV_V xpol
                             ,XXD_PO_HEADERS_STG_T      xpoh
               WHERE  xpol.po_header_id = xpoh.po_header_id ; */

        CURSOR c_get_line_rec IS
            SELECT xpol.*
              --FROM XXD_PO_LINES_CONV_V xpol;
              FROM xxd_po_lines_conv_1206 xpol, XXD_PO_HEADERS_STG_T xpoh --Removed extract view with dump tables on 19-May-2015
             WHERE xpol.po_header_id = xpoh.po_header_id; --Added condition on 29-Jul-2015

        TYPE lt_po_line_typ IS TABLE OF c_get_line_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_line_data        lt_po_line_typ;
    BEGIN
        x_ret_code         := gn_suc_const;
        write_log ('Start of extract_po_lines  procedure');

        lt_po_line_type.DELETE;
        ln_valid_rec_cnt   := 0;

        OPEN c_get_line_rec;

        LOOP
            lt_po_line_data.delete;
            SAVEPOINT INSERT_TABLE4;

            FETCH c_get_line_rec BULK COLLECT INTO lt_po_line_data LIMIT 5000;

            EXIT WHEN lt_po_line_data.COUNT = 0;

            --   EXIT WHEN c_get_line_rec%ROWCOUNT = 0;

            IF lt_po_line_data.COUNT > 0
            THEN
                write_log (
                       'Inserting in to list lines table Row count :'
                    || lt_po_line_data.COUNT);
                ln_valid_rec_cnt   := 0;
                lt_po_line_type.delete;

                FOR list_line_rec_cnt IN lt_po_line_data.FIRST ..
                                         lt_po_line_data.LAST
                LOOP
                    ln_count           := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --
                    --write_log ('Row count :' || ln_valid_rec_cnt);
                    lt_po_line_type (ln_valid_rec_cnt).RECORD_STATUS   :=
                        gc_new_status;
                    lt_po_line_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).INTERFACE_LINE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).INTERFACE_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).ACTION   :=
                        lt_po_line_data (list_line_rec_cnt).ACTION;
                    lt_po_line_type (ln_valid_rec_cnt).GROUP_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).GROUP_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).PO_LINE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PO_LINE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_LOCATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_LOCATION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_TYPE   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_TYPE;
                    lt_po_line_type (ln_valid_rec_cnt).REQUISITION_LINE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).REQUISITION_LINE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).DOCUMENT_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).DOCUMENT_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).RELEASE_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).RELEASE_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PO_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).PO_RELEASE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PO_RELEASE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).SOURCE_SHIPMENT_ID   :=
                        lt_po_line_data (list_line_rec_cnt).SOURCE_SHIPMENT_ID;
                    lt_po_line_type (ln_valid_rec_cnt).CONTRACT_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).CONTRACT_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_TYPE   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_TYPE;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_TYPE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_TYPE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ID   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ID;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_REVISION   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_REVISION;
                    lt_po_line_type (ln_valid_rec_cnt).CATEGORY_SEGMENT1   :=
                        lt_po_line_data (list_line_rec_cnt).CATEGORY_SEGMENT1;
                    lt_po_line_type (ln_valid_rec_cnt).CATEGORY   :=
                        lt_po_line_data (list_line_rec_cnt).CATEGORY;

                    --lt_po_line_type (ln_valid_rec_cnt).CATEGORY_ID                        :=    lt_po_line_data (list_line_rec_cnt).CATEGORY_ID        ;
                    -------Start of changes 03-Aug-2015
                    BEGIN
                        SELECT msb.DESCRIPTION
                          INTO l_item_desc
                          FROM MTL_SYSTEM_ITEMS_B msb, mtl_parameters mp
                         WHERE     msb.organization_id = mp.organization_id
                               AND msb.segment1 =
                                   lt_po_line_data (list_line_rec_cnt).ITEM
                               AND mp.organization_code = 'MST';

                        write_log (
                               'Item Description found for the item - '
                            || lt_po_line_data (list_line_rec_cnt).ITEM
                            || ' is '
                            || l_item_desc);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            write_log (
                                   'No Description found for the item - '
                                || lt_po_line_data (list_line_rec_cnt).ITEM);
                            l_item_desc   := NULL;
                        WHEN OTHERS
                        THEN
                            write_log (
                                   'Error in retrieving Description for Item  - '
                                || lt_po_line_data (list_line_rec_cnt).ITEM
                                || SQLERRM);
                            l_item_desc   := NULL;
                    END;

                    -------End of changes 03-Aug-2015
                    --Modified on  08-MAY-2015
                    --lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION :=  lt_po_line_data (list_line_rec_cnt).ITEM; --ITEM_DESCRIPTION        ;
                    --lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION := lt_po_line_data (list_line_rec_cnt).ITEM_DESCRIPTION;  --Commented on 03-Aug-2015 for resolution of Item Desc error
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_DESCRIPTION   :=
                        l_item_desc; --Added on 03-Aug-2015 for resolution of Item Desc error

                    --Modified on  08-MAY-2015
                    lt_po_line_type (ln_valid_rec_cnt).VENDOR_PRODUCT_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).VENDOR_PRODUCT_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).UOM_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).UOM_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).UNIT_OF_MEASURE   :=
                        lt_po_line_data (list_line_rec_cnt).UNIT_OF_MEASURE;
                    lt_po_line_type (ln_valid_rec_cnt).QUANTITY   :=
                        lt_po_line_data (list_line_rec_cnt).QUANTITY;
                    lt_po_line_type (ln_valid_rec_cnt).COMMITTED_AMOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).COMMITTED_AMOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).MIN_ORDER_QUANTITY   :=
                        lt_po_line_data (list_line_rec_cnt).MIN_ORDER_QUANTITY;
                    lt_po_line_type (ln_valid_rec_cnt).MAX_ORDER_QUANTITY   :=
                        lt_po_line_data (list_line_rec_cnt).MAX_ORDER_QUANTITY;
                    lt_po_line_type (ln_valid_rec_cnt).UNIT_PRICE   :=
                        lt_po_line_data (list_line_rec_cnt).UNIT_PRICE;
                    lt_po_line_type (ln_valid_rec_cnt).LIST_PRICE_PER_UNIT   :=
                        lt_po_line_data (list_line_rec_cnt).LIST_PRICE_PER_UNIT;
                    lt_po_line_type (ln_valid_rec_cnt).MARKET_PRICE   :=
                        lt_po_line_data (list_line_rec_cnt).MARKET_PRICE;
                    --                lt_po_line_type (ln_valid_rec_cnt).ALLOW_PRICE_OVERRIDE_FLAG          :=    lt_po_line_data (list_line_rec_cnt).ALLOW_PRICE_OVERRIDE_FLAG        ;
                    lt_po_line_type (ln_valid_rec_cnt).NOT_TO_EXCEED_PRICE   :=
                        lt_po_line_data (list_line_rec_cnt).NOT_TO_EXCEED_PRICE;
                    --                lt_po_line_type (ln_valid_rec_cnt).NEGOTIATED_BY_PREPARER_FLAG        :=    lt_po_line_data (list_line_rec_cnt).NEGOTIATED_BY_PREPARER_FLAG        ;
                    lt_po_line_type (ln_valid_rec_cnt).UN_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).UN_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).UN_NUMBER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).UN_NUMBER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).HAZARD_CLASS   :=
                        lt_po_line_data (list_line_rec_cnt).HAZARD_CLASS;
                    lt_po_line_type (ln_valid_rec_cnt).HAZARD_CLASS_ID   :=
                        lt_po_line_data (list_line_rec_cnt).HAZARD_CLASS_ID;
                    lt_po_line_type (ln_valid_rec_cnt).NOTE_TO_VENDOR   :=
                        lt_po_line_data (list_line_rec_cnt).NOTE_TO_VENDOR;
                    lt_po_line_type (ln_valid_rec_cnt).TRANSACTION_REASON_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).TRANSACTION_REASON_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).TAXABLE_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).TAXABLE_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).TAX_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).TAX_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).TYPE_1099   :=
                        lt_po_line_data (list_line_rec_cnt).TYPE_1099;
                    lt_po_line_type (ln_valid_rec_cnt).CAPITAL_EXPENSE_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).CAPITAL_EXPENSE_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).INSPECTION_REQUIRED_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).INSPECTION_REQUIRED_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).RECEIPT_REQUIRED_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).RECEIPT_REQUIRED_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).PAYMENT_TERMS   :=
                        lt_po_line_data (list_line_rec_cnt).PAYMENT_TERMS;
                    lt_po_line_type (ln_valid_rec_cnt).TERMS_ID   :=
                        lt_po_line_data (list_line_rec_cnt).TERMS_ID;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_TYPE   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_TYPE;
                    lt_po_line_type (ln_valid_rec_cnt).MIN_RELEASE_AMOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).MIN_RELEASE_AMOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_BREAK_LOOKUP_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_BREAK_LOOKUP_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).USSGL_TRANSACTION_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).USSGL_TRANSACTION_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).CLOSED_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).CLOSED_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).CLOSED_REASON   :=
                        lt_po_line_data (list_line_rec_cnt).CLOSED_REASON;
                    lt_po_line_type (ln_valid_rec_cnt).CLOSED_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).CLOSED_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).CLOSED_BY   :=
                        lt_po_line_data (list_line_rec_cnt).CLOSED_BY;
                    lt_po_line_type (ln_valid_rec_cnt).INVOICE_CLOSE_TOLERANCE   :=
                        lt_po_line_data (list_line_rec_cnt).INVOICE_CLOSE_TOLERANCE;
                    lt_po_line_type (ln_valid_rec_cnt).RECEIVE_CLOSE_TOLERANCE   :=
                        lt_po_line_data (list_line_rec_cnt).RECEIVE_CLOSE_TOLERANCE;
                    lt_po_line_type (ln_valid_rec_cnt).FIRM_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).FIRM_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED   :=
                        lt_po_line_data (list_line_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED;
                    lt_po_line_type (ln_valid_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED   :=
                        lt_po_line_data (list_line_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED;
                    lt_po_line_type (ln_valid_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).RECEIVING_ROUTING   :=
                        lt_po_line_data (list_line_rec_cnt).RECEIVING_ROUTING;
                    lt_po_line_type (ln_valid_rec_cnt).RECEIVING_ROUTING_ID   :=
                        lt_po_line_data (list_line_rec_cnt).RECEIVING_ROUTING_ID;
                    lt_po_line_type (ln_valid_rec_cnt).QTY_RCV_TOLERANCE   :=
                        lt_po_line_data (list_line_rec_cnt).QTY_RCV_TOLERANCE;
                    lt_po_line_type (ln_valid_rec_cnt).OVER_TOLERANCE_ERROR_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).OVER_TOLERANCE_ERROR_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).QTY_RCV_EXCEPTION_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).QTY_RCV_EXCEPTION_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).SHIP_TO_ORGANIZATION_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).SHIP_TO_ORGANIZATION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                        lt_po_line_data (list_line_rec_cnt).SHIP_TO_LOCATION;
                    lt_po_line_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).SHIP_TO_LOCATION_ID;



                    lt_po_line_type (ln_valid_rec_cnt).NEED_BY_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).NEED_BY_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).PROMISED_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).PROMISED_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).ACCRUE_ON_RECEIPT_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).LEAD_TIME   :=
                        lt_po_line_data (list_line_rec_cnt).LEAD_TIME;
                    lt_po_line_type (ln_valid_rec_cnt).LEAD_TIME_UNIT   :=
                        lt_po_line_data (list_line_rec_cnt).LEAD_TIME_UNIT;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_DISCOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_DISCOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).FREIGHT_CARRIER   :=
                        lt_po_line_data (list_line_rec_cnt).FREIGHT_CARRIER;
                    lt_po_line_type (ln_valid_rec_cnt).FOB   :=
                        lt_po_line_data (list_line_rec_cnt).FOB;
                    lt_po_line_type (ln_valid_rec_cnt).FREIGHT_TERMS   :=
                        lt_po_line_data (list_line_rec_cnt).FREIGHT_TERMS;
                    lt_po_line_type (ln_valid_rec_cnt).EFFECTIVE_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).EFFECTIVE_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).EXPIRATION_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).EXPIRATION_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).FROM_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).FROM_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).FROM_LINE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).FROM_LINE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).FROM_LINE_LOCATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).FROM_LINE_LOCATION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE_CATEGORY_LINES   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE_CATEGORY_LINES;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE1   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE1;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE2   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE2;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE3   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE3;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE4   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE4;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE5   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE5;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE6   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE6;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE7   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE7;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE8   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE8;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE9   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE9;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE10   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE10;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE11   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE11;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE12   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE12;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE13   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE13;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE14   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE14;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_ATTRIBUTE15   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_ATTRIBUTE15;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE_CATEGORY   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE_CATEGORY;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE1   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE1;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE2   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE2;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE3   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE3;
                    --lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE4                :=    lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE4        ;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'SHIPMENT_ATTRIBUTE4 '
                        || lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE4);
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE4   :=
                        TO_CHAR (
                            TO_DATE (
                                lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE4,
                                'DD-MON-YY'),
                            'YYYY/MM/DD HH12:MI:SS');

                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE5   :=
                        TO_CHAR (
                            TO_DATE (
                                lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE5,
                                'DD-MON-YY'),
                            'YYYY/MM/DD HH12:MI:SS');

                    --lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE5 :=                  lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE5;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE6   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE6;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE7   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE7;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE8   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE8;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE9   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE9;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE10   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE10;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE11   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE11;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE12   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE12;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE13   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE13;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE14   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE14;
                    lt_po_line_type (ln_valid_rec_cnt).SHIPMENT_ATTRIBUTE15   :=
                        lt_po_line_data (list_line_rec_cnt).SHIPMENT_ATTRIBUTE15;
                    lt_po_line_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).LAST_UPDATE_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                        lt_po_line_data (list_line_rec_cnt).LAST_UPDATED_BY;
                    lt_po_line_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                        lt_po_line_data (list_line_rec_cnt).LAST_UPDATE_LOGIN;
                    lt_po_line_type (ln_valid_rec_cnt).CREATION_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).CREATION_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).CREATED_BY   :=
                        lt_po_line_data (list_line_rec_cnt).CREATED_BY;
                    lt_po_line_type (ln_valid_rec_cnt).REQUEST_ID   :=
                        gn_conc_request_id; --lt_po_line_data (list_line_rec_cnt).REQUEST_ID        ;
                    lt_po_line_type (ln_valid_rec_cnt).PROGRAM_APPLICATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PROGRAM_APPLICATION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).PROGRAM_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PROGRAM_ID;
                    lt_po_line_type (ln_valid_rec_cnt).PROGRAM_UPDATE_DATE   :=
                        lt_po_line_data (list_line_rec_cnt).PROGRAM_UPDATE_DATE;
                    lt_po_line_type (ln_valid_rec_cnt).ORGANIZATION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).ORGANIZATION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE_CATEGORY   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE_CATEGORY;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE1   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE1;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE2   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE2;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE3   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE3;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE4   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE4;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE5   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE5;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE6   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE6;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE7   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE7;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE8   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE8;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE9   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE9;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE10   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE10;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE11   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE11;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE12   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE12;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE13   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE13;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE14   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE14;
                    lt_po_line_type (ln_valid_rec_cnt).ITEM_ATTRIBUTE15   :=
                        lt_po_line_data (list_line_rec_cnt).ITEM_ATTRIBUTE15;
                    lt_po_line_type (ln_valid_rec_cnt).UNIT_WEIGHT   :=
                        lt_po_line_data (list_line_rec_cnt).UNIT_WEIGHT;
                    lt_po_line_type (ln_valid_rec_cnt).WEIGHT_UOM_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).WEIGHT_UOM_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).VOLUME_UOM_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).VOLUME_UOM_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).UNIT_VOLUME   :=
                        lt_po_line_data (list_line_rec_cnt).UNIT_VOLUME;
                    lt_po_line_type (ln_valid_rec_cnt).TEMPLATE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).TEMPLATE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).TEMPLATE_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).TEMPLATE_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_REFERENCE_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_REFERENCE_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).SOURCING_RULE_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).SOURCING_RULE_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).TAX_STATUS_INDICATOR   :=
                        lt_po_line_data (list_line_rec_cnt).TAX_STATUS_INDICATOR;
                    lt_po_line_type (ln_valid_rec_cnt).PROCESS_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).PROCESS_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_CHG_ACCEPT_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_CHG_ACCEPT_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_BREAK_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_BREAK_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).PRICE_UPDATE_TOLERANCE   :=
                        lt_po_line_data (list_line_rec_cnt).PRICE_UPDATE_TOLERANCE;
                    lt_po_line_type (ln_valid_rec_cnt).TAX_USER_OVERRIDE_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).TAX_USER_OVERRIDE_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).TAX_CODE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).TAX_CODE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).NOTE_TO_RECEIVER   :=
                        lt_po_line_data (list_line_rec_cnt).NOTE_TO_RECEIVER;
                    lt_po_line_type (ln_valid_rec_cnt).OKE_CONTRACT_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).OKE_CONTRACT_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).OKE_CONTRACT_HEADER_NUM   :=
                        lt_po_line_data (list_line_rec_cnt).OKE_CONTRACT_HEADER_NUM;
                    lt_po_line_type (ln_valid_rec_cnt).OKE_CONTRACT_VERSION_ID   :=
                        lt_po_line_data (list_line_rec_cnt).OKE_CONTRACT_VERSION_ID;
                    lt_po_line_type (ln_valid_rec_cnt).SECONDARY_UNIT_OF_MEASURE   :=
                        lt_po_line_data (list_line_rec_cnt).SECONDARY_UNIT_OF_MEASURE;
                    lt_po_line_type (ln_valid_rec_cnt).SECONDARY_UOM_CODE   :=
                        lt_po_line_data (list_line_rec_cnt).SECONDARY_UOM_CODE;
                    lt_po_line_type (ln_valid_rec_cnt).SECONDARY_QUANTITY   :=
                        lt_po_line_data (list_line_rec_cnt).SECONDARY_QUANTITY;
                    lt_po_line_type (ln_valid_rec_cnt).PREFERRED_GRADE   :=
                        lt_po_line_data (list_line_rec_cnt).PREFERRED_GRADE;
                    lt_po_line_type (ln_valid_rec_cnt).VMI_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).VMI_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).AUCTION_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).AUCTION_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).AUCTION_LINE_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).AUCTION_LINE_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).AUCTION_DISPLAY_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).AUCTION_DISPLAY_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).BID_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).BID_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).BID_LINE_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).BID_LINE_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).ORIG_FROM_REQ_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).ORIG_FROM_REQ_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).CONSIGNED_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).CONSIGNED_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).SUPPLIER_REF_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).SUPPLIER_REF_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).CONTRACT_ID   :=
                        lt_po_line_data (list_line_rec_cnt).CONTRACT_ID;
                    lt_po_line_type (ln_valid_rec_cnt).JOB_ID   :=
                        lt_po_line_data (list_line_rec_cnt).JOB_ID;
                    lt_po_line_type (ln_valid_rec_cnt).AMOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).AMOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).JOB_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).JOB_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).CONTRACTOR_FIRST_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).CONTRACTOR_FIRST_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).CONTRACTOR_LAST_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).CONTRACTOR_LAST_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).DROP_SHIP_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).DROP_SHIP_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).BASE_UNIT_PRICE   :=
                        lt_po_line_data (list_line_rec_cnt).BASE_UNIT_PRICE;
                    lt_po_line_type (ln_valid_rec_cnt).TRANSACTION_FLOW_HEADER_ID   :=
                        lt_po_line_data (list_line_rec_cnt).TRANSACTION_FLOW_HEADER_ID;
                    lt_po_line_type (ln_valid_rec_cnt).JOB_BUSINESS_GROUP_ID   :=
                        lt_po_line_data (list_line_rec_cnt).JOB_BUSINESS_GROUP_ID;
                    lt_po_line_type (ln_valid_rec_cnt).JOB_BUSINESS_GROUP_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).JOB_BUSINESS_GROUP_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).CATALOG_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).CATALOG_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).SUPPLIER_PART_AUXID   :=
                        lt_po_line_data (list_line_rec_cnt).SUPPLIER_PART_AUXID;
                    lt_po_line_type (ln_valid_rec_cnt).IP_CATEGORY_ID   :=
                        lt_po_line_data (list_line_rec_cnt).IP_CATEGORY_ID;
                    lt_po_line_type (ln_valid_rec_cnt).TRACKING_QUANTITY_IND   :=
                        lt_po_line_data (list_line_rec_cnt).TRACKING_QUANTITY_IND;
                    lt_po_line_type (ln_valid_rec_cnt).SECONDARY_DEFAULT_IND   :=
                        lt_po_line_data (list_line_rec_cnt).SECONDARY_DEFAULT_IND;
                    lt_po_line_type (ln_valid_rec_cnt).DUAL_UOM_DEVIATION_HIGH   :=
                        lt_po_line_data (list_line_rec_cnt).DUAL_UOM_DEVIATION_HIGH;
                    lt_po_line_type (ln_valid_rec_cnt).DUAL_UOM_DEVIATION_LOW   :=
                        lt_po_line_data (list_line_rec_cnt).DUAL_UOM_DEVIATION_LOW;
                    lt_po_line_type (ln_valid_rec_cnt).PROCESSING_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PROCESSING_ID;
                    lt_po_line_type (ln_valid_rec_cnt).LINE_LOC_POPULATED_FLAG   :=
                        lt_po_line_data (list_line_rec_cnt).LINE_LOC_POPULATED_FLAG;
                    lt_po_line_type (ln_valid_rec_cnt).IP_CATEGORY_NAME   :=
                        lt_po_line_data (list_line_rec_cnt).IP_CATEGORY_NAME;
                    lt_po_line_type (ln_valid_rec_cnt).RETAINAGE_RATE   :=
                        lt_po_line_data (list_line_rec_cnt).RETAINAGE_RATE;
                    lt_po_line_type (ln_valid_rec_cnt).MAX_RETAINAGE_AMOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).MAX_RETAINAGE_AMOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).PROGRESS_PAYMENT_RATE   :=
                        lt_po_line_data (list_line_rec_cnt).PROGRESS_PAYMENT_RATE;
                    lt_po_line_type (ln_valid_rec_cnt).RECOUPMENT_RATE   :=
                        lt_po_line_data (list_line_rec_cnt).RECOUPMENT_RATE;
                    lt_po_line_type (ln_valid_rec_cnt).ADVANCE_AMOUNT   :=
                        lt_po_line_data (list_line_rec_cnt).ADVANCE_AMOUNT;
                    lt_po_line_type (ln_valid_rec_cnt).FILE_LINE_NUMBER   :=
                        lt_po_line_data (list_line_rec_cnt).FILE_LINE_NUMBER;
                    lt_po_line_type (ln_valid_rec_cnt).PARENT_INTERFACE_LINE_ID   :=
                        lt_po_line_data (list_line_rec_cnt).PARENT_INTERFACE_LINE_ID;
                    lt_po_line_type (ln_valid_rec_cnt).FILE_LINE_LANGUAGE   :=
                        lt_po_line_data (list_line_rec_cnt).FILE_LINE_LANGUAGE;
                END LOOP;

                write_log (
                    'Bulk Insert  in to list lines table XXD_PO_LINES_STG_T');

                -------------------------------------------------------------------
                -- do a bulk insert into the XXD_PO_LINES_STG_T table
                ----------------------------------------------------------------
                FORALL ln_cnt IN 1 .. lt_po_line_type.COUNT SAVE EXCEPTIONS
                    INSERT INTO XXD_PO_LINES_STG_T
                         VALUES lt_po_line_type (ln_cnt);
            END IF;

            COMMIT;
        END LOOP;

        IF c_get_line_rec%ISOPEN
        THEN
            CLOSE c_get_line_rec;
        END IF;
    --           x_rec_count        :=x_rec_count +  ln_valid_rec_cnt;
    --           ln_valid_rec_cnt := 0;
    --           lt_PO_list_line_type.delete;
    --      END LOOP;

    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE4;
            x_ret_code   := gn_err_const;

            IF c_get_line_rec%ISOPEN
            THEN
                CLOSE c_get_line_rec;
            END IF;

            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --   SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --   SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'XXD_PO_LINES_STG_T', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE4;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_line_rec%ISOPEN
            THEN
                CLOSE c_get_line_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --   SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'XXD_PO_LINES_STG_T',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE4;
            x_ret_code   := gn_err_const;
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_line_rec%ISOPEN
            THEN
                CLOSE c_get_line_rec;
            END IF;

            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --    SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'XXD_PO_LINES_STG_T',
                NULL,
                'Unexpected Exception while inserting into XXD_PO_LINES_STG_T');
    END extract_po_lines;

    PROCEDURE extract_po_line_locations (x_ret_code OUT VARCHAR2, x_rec_count OUT NUMBER, x_return_mesg OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_po_line_locations                                      *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a      04-JUL-2014     BT Technology Team     Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_p0_line_locations_t
            IS TABLE OF XXD_PO_LINE_LOCATIONS_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_p0_line_locations_type   type_p0_line_locations_t;
        ln_valid_rec_cnt            NUMBER := 0;
        ln_count                    NUMBER := 0;
        ln_int_run_id               NUMBER;
        l_bulk_errors               NUMBER := 0;
        ex_bulk_exceptions          EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception        EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the  records from 12.0.3 table
        ----------------------------------------------------------
        /*      CURSOR c_get_line_locations_rec
              IS
                 SELECT xpll.*
                  FROM   XXD_PO_LINE_LOCATION_CONV_V xpll
                              , XXD_PO_LINES_STG_T xpol
                 WHERE xpll.po_header_id = xpol.po_header_id
                        and xpll.po_line_id = xpol.po_line_id  ;
        */
        CURSOR c_get_line_locations_rec IS
            SELECT xpll.*
              -- FROM XXD_PO_LINE_LOCATION_CONV_V xpll;
              FROM xxd_po_line_locatn_conv_1206 xpll, XXD_PO_LINES_STG_T xpol --Removed extract view with Dump Table on 19-May-2015
             WHERE     xpll.po_header_id = xpol.po_header_id --Added condition on 29-Jul-2015
                   AND xpll.po_line_id = xpol.po_line_id; --Added condition on 29-Jul-2015


        --WHERE LIST_HEADER_ID = p_list_header_id
        --AND LIST_LINE_ID     = p_list_line_id;

        TYPE lt_po_line_locations_typ
            IS TABLE OF c_get_line_locations_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_line_locations_data      lt_po_line_locations_typ;
    BEGIN
        x_ret_code         := gn_suc_const;
        write_log ('Start of extract_po_line_locations  procedure');

        lt_p0_line_locations_type.DELETE;
        ln_valid_rec_cnt   := 0;

        OPEN c_get_line_locations_rec;

        LOOP
            SAVEPOINT INSERT_TABLE3;

            FETCH c_get_line_locations_rec
                BULK COLLECT INTO lt_line_locations_data
                LIMIT 5000;

            EXIT WHEN lt_line_locations_data.COUNT = 0;


            IF lt_line_locations_data.COUNT > 0
            THEN
                write_log (
                       'Inserting in to pricing attribs table Row count :'
                    || lt_line_locations_data.COUNT);
                ln_valid_rec_cnt   := 0;
                lt_p0_line_locations_type.delete;

                FOR line_locattion_rec_cnt IN lt_line_locations_data.FIRST ..
                                              lt_line_locations_data.LAST
                LOOP
                    ln_count           := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;             --
                    lt_p0_line_locations_type (ln_valid_rec_cnt).INTERFACE_LINE_LOCATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).INTERFACE_LINE_LOCATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).INTERFACE_HEADER_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).INTERFACE_LINE_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECORD_STATUS   :=
                        gc_new_status;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROCESSING_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROCESSING_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROCESS_CODE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROCESS_CODE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PO_HEADER_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PO_LINE_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PO_LINE_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LINE_LOCATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LINE_LOCATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIPMENT_TYPE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIPMENT_TYPE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIPMENT_NUM   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIPMENT_NUM;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIP_TO_ORGANIZATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIP_TO_ORGANIZATION_CODE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIP_TO_ORGANIZATION_CODE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIP_TO_LOCATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIP_TO_LOCATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SHIP_TO_LOCATION   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SHIP_TO_LOCATION;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TERMS_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TERMS_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PAYMENT_TERMS   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PAYMENT_TERMS;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).QTY_RCV_EXCEPTION_CODE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).QTY_RCV_EXCEPTION_CODE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).FREIGHT_CARRIER   :=
                        lt_line_locations_data (line_locattion_rec_cnt).FREIGHT_CARRIER;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).FOB   :=
                        lt_line_locations_data (line_locattion_rec_cnt).FOB;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).FREIGHT_TERMS   :=
                        lt_line_locations_data (line_locattion_rec_cnt).FREIGHT_TERMS;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ENFORCE_SHIP_TO_LOCATION_CODE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ALLOW_SUBSTITUTE_RECEIPTS_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED   :=
                        lt_line_locations_data (line_locattion_rec_cnt).DAYS_EARLY_RECEIPT_ALLOWED;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED   :=
                        lt_line_locations_data (line_locattion_rec_cnt).DAYS_LATE_RECEIPT_ALLOWED;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).RECEIPT_DAYS_EXCEPTION_CODE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).INVOICE_CLOSE_TOLERANCE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).INVOICE_CLOSE_TOLERANCE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECEIVE_CLOSE_TOLERANCE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).RECEIVE_CLOSE_TOLERANCE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECEIVING_ROUTING_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).RECEIVING_ROUTING_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECEIVING_ROUTING   :=
                        lt_line_locations_data (line_locattion_rec_cnt).RECEIVING_ROUTING;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ACCRUE_ON_RECEIPT_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).FIRM_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).FIRM_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).NEED_BY_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).NEED_BY_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROMISED_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROMISED_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).FROM_LINE_LOCATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).FROM_LINE_LOCATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).INSPECTION_REQUIRED_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).INSPECTION_REQUIRED_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).RECEIPT_REQUIRED_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).RECEIPT_REQUIRED_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SOURCE_SHIPMENT_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SOURCE_SHIPMENT_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).NOTE_TO_RECEIVER   :=
                        lt_line_locations_data (line_locattion_rec_cnt).NOTE_TO_RECEIVER;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TRANSACTION_FLOW_HEADER_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TRANSACTION_FLOW_HEADER_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).QUANTITY   :=
                        lt_line_locations_data (line_locattion_rec_cnt).QUANTITY;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PRICE_DISCOUNT   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PRICE_DISCOUNT;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).START_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).START_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).END_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).END_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PRICE_OVERRIDE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PRICE_OVERRIDE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LEAD_TIME   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LEAD_TIME;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LEAD_TIME_UNIT   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LEAD_TIME_UNIT;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).AMOUNT   :=
                        lt_line_locations_data (line_locattion_rec_cnt).AMOUNT;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SECONDARY_QUANTITY   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SECONDARY_QUANTITY;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).SECONDARY_UNIT_OF_MEASURE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).SECONDARY_UNIT_OF_MEASURE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE_CATEGORY;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE1;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE2;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE3;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE4;
                    --lt_p0_line_locations_type(ln_valid_rec_cnt).ATTRIBUTE4                         :=     fnd_date.canonical_to_date(to_date(lt_line_locations_data(line_locattion_rec_cnt).ATTRIBUTE4,'YYYY/MM/DD HH:MI:SS AM'));
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE5;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE6;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE7;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE8;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE9;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE10;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE11;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE12;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE13;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE14;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                        lt_line_locations_data (line_locattion_rec_cnt).ATTRIBUTE15;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CREATION_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CREATION_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CREATED_BY   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CREATED_BY;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LAST_UPDATE_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LAST_UPDATED_BY;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                        lt_line_locations_data (line_locattion_rec_cnt).LAST_UPDATE_LOGIN;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).REQUEST_ID   :=
                        gn_conc_request_id; -- lt_line_locations_data(line_locattion_rec_cnt).REQUEST_ID    ;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROGRAM_APPLICATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROGRAM_APPLICATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROGRAM_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROGRAM_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROGRAM_UPDATE_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROGRAM_UPDATE_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).UNIT_OF_MEASURE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).UNIT_OF_MEASURE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PAYMENT_TYPE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PAYMENT_TYPE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).DESCRIPTION   :=
                        lt_line_locations_data (line_locattion_rec_cnt).DESCRIPTION;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).WORK_APPROVER_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).WORK_APPROVER_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).AUCTION_PAYMENT_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).AUCTION_PAYMENT_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).BID_PAYMENT_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).BID_PAYMENT_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PROJECT_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PROJECT_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TASK_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TASK_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).AWARD_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).AWARD_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).EXPENDITURE_TYPE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).EXPENDITURE_TYPE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).EXPENDITURE_ORGANIZATION_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).EXPENDITURE_ITEM_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).EXPENDITURE_ITEM_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).VALUE_BASIS   :=
                        lt_line_locations_data (line_locattion_rec_cnt).VALUE_BASIS;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).MATCHING_BASIS   :=
                        lt_line_locations_data (line_locattion_rec_cnt).MATCHING_BASIS;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).PREFERRED_GRADE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).PREFERRED_GRADE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TAX_CODE_ID   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TAX_CODE_ID;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TAX_NAME   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TAX_NAME;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).TAXABLE_FLAG   :=
                        lt_line_locations_data (line_locattion_rec_cnt).TAXABLE_FLAG;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).QTY_RCV_TOLERANCE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).QTY_RCV_TOLERANCE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_DELIVERY_PERIOD   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_DELIVERY_PERIOD;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_DELIVERY_PERIOD_UOM   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_DELIVERY_PERIOD_UOM;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_POP_DURATION   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_POP_DURATION;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_POP_DURATION_UOM   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_POP_DURATION_UOM;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_PROMISE_PERIOD   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_PROMISE_PERIOD;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_PROMISE_PERIOD_UOM   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_PROMISE_PERIOD_UOM;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_PERIOD_PERF_START_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_PERIOD_PERF_START_DATE;
                    lt_p0_line_locations_type (ln_valid_rec_cnt).CLM_PERIOD_PERF_END_DATE   :=
                        lt_line_locations_data (line_locattion_rec_cnt).CLM_PERIOD_PERF_END_DATE;
                END LOOP;


                -------------------------------------------------------------------
                -- do a bulk insert into the XXD_PO_LIST_LINES_STG_T table
                ----------------------------------------------------------------
                write_log (
                    'Bulk Insert  in to list lines table XXD_PO_LINE_LOCATIONS_STG_T');

                FORALL ln_cnt IN 1 .. lt_p0_line_locations_type.COUNT
                  SAVE EXCEPTIONS
                    INSERT INTO XXD_PO_LINE_LOCATIONS_STG_T
                         VALUES lt_p0_line_locations_type (ln_cnt);
            END IF;

            COMMIT;
        END LOOP;

        IF c_get_line_locations_rec%ISOPEN
        THEN
            CLOSE c_get_line_locations_rec;
        END IF;

        x_rec_count        := ln_valid_rec_cnt;
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;

            IF c_get_line_locations_rec%ISOPEN
            THEN
                CLOSE c_get_line_locations_rec;
            END IF;

            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --   SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --   SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'XXD_PO_LINE_LOCATIONS_STG_T', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE3;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_line_locations_rec%ISOPEN
            THEN
                CLOSE c_get_line_locations_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --    SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --     SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'XXD_PO_LINE_LOCATIONS_STG_T',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE3;
            x_ret_code   := gn_err_const;
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_line_locations_rec%ISOPEN
            THEN
                CLOSE c_get_line_locations_rec;
            END IF;

            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --  SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'XXD_PO_LINE_LOCATIONS_STG_T',
                NULL,
                'Unexpected Exception while inserting into XXD_PO_LINE_LOCATIONS_STG_T');
    END extract_po_line_locations;

    PROCEDURE extract_po_distribution (x_ret_code OUT VARCHAR2, x_rec_count OUT NUMBER, x_return_mesg OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :   extract_po_distribution                                            *
    *                                                                                             *
    * Description          :  This procedure will populate the Data to Stage Table                *
    *                                                                                             *
    * Parameters         Type       Description                                                   *
    * ---------------    ----       ---------------------                                         *
    * x_ret_code         OUT        Return Code                                                   *
    * x_rec_count        OUT        No of records transferred to Stage table                      *
    * x_int_run_id       OUT        Interface Run Id                                              *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a      04-JUL-2014     BT Technology Team     Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_po_distributions_t
            IS TABLE OF XXD_PO_DISTRIBUTIONS_STG_T%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_po_distributions_type   type_po_distributions_t;
        ln_valid_rec_cnt           NUMBER := 0;
        ln_count                   NUMBER := 0;
        ln_int_run_id              NUMBER;
        l_bulk_errors              NUMBER := 0;
        ex_bulk_exceptions         EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception       EXCEPTION;

        --------------------------------------------------------
        --Cursor to fetch the  records from 12.0.3 table
        ----------------------------------------------------------
        /*     CURSOR c_get_distributions_rec
             IS
                SELECT xpod.*
                  FROM XXD_PO_DISTRIBUTIONS_CONV_V xpod
                             ,XXD_PO_HEADERS_STG_T xpoh
               WHERE  xpod.PO_HEADER_ID = xpoh.PO_HEADER_ID;
       */
        CURSOR c_get_distributions_rec IS
            SELECT xpod.*
              -- FROM XXD_PO_DISTRIBUTIONS_CONV_V xpod;
              FROM xxd_po_distributions_conv_1206 xpod, --Removed extract view with Dump Table on 19-May-2015
                                                        XXD_PO_HEADERS_STG_T xpoh --Added table on 29-Jul-2015
             WHERE xpod.PO_HEADER_ID = xpoh.PO_HEADER_ID; --Added condition on 29-Jul-2015

        TYPE lt_distributions_typ IS TABLE OF c_get_distributions_rec%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_distributions_data      lt_distributions_typ;
    BEGIN
        x_ret_code         := gn_suc_const;
        write_log ('Start of extract_po_distribution procedure');

        lt_po_distributions_type.DELETE;
        ln_valid_rec_cnt   := 0;

        OPEN c_get_distributions_rec;

        LOOP
            SAVEPOINT INSERT_TABLE2;

            FETCH c_get_distributions_rec
                BULK COLLECT INTO lt_distributions_data
                LIMIT 5000;

            EXIT WHEN lt_distributions_data.COUNT = 0;

            --  CLOSE c_get_distributions_rec;

            IF lt_distributions_data.COUNT > 0
            THEN
                write_log (
                       'Inserting in to list lines table Row count :'
                    || lt_distributions_data.COUNT);
                ln_valid_rec_cnt   := 0;
                lt_po_distributions_type.delete;

                FOR distributions_rec_cnt IN lt_distributions_data.FIRST ..
                                             lt_distributions_data.LAST
                LOOP
                    ln_count           := ln_count + 1;
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;
                    --
                    lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_HEADER_ID   :=
                        lt_distributions_data (distributions_rec_cnt).INTERFACE_HEADER_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_LINE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).INTERFACE_LINE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_DISTRIBUTION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).INTERFACE_DISTRIBUTION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).RECORD_STATUS   :=
                        gc_new_status;
                    lt_po_distributions_type (ln_valid_rec_cnt).PO_HEADER_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PO_HEADER_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PO_RELEASE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PO_RELEASE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PO_LINE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PO_LINE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).LINE_LOCATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).LINE_LOCATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PO_DISTRIBUTION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PO_DISTRIBUTION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).DISTRIBUTION_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).DISTRIBUTION_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).SOURCE_DISTRIBUTION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).SOURCE_DISTRIBUTION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).ORG_ID   :=
                        lt_distributions_data (distributions_rec_cnt).ORG_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_ORDERED   :=
                        lt_distributions_data (distributions_rec_cnt).QUANTITY_ORDERED;
                    lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_DELIVERED   :=
                        lt_distributions_data (distributions_rec_cnt).QUANTITY_DELIVERED;
                    lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_BILLED   :=
                        lt_distributions_data (distributions_rec_cnt).QUANTITY_BILLED;
                    lt_po_distributions_type (ln_valid_rec_cnt).QUANTITY_CANCELLED   :=
                        lt_distributions_data (distributions_rec_cnt).QUANTITY_CANCELLED;
                    lt_po_distributions_type (ln_valid_rec_cnt).RATE_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).RATE_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).RATE   :=
                        lt_distributions_data (distributions_rec_cnt).RATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_LOCATION   :=
                        lt_distributions_data (distributions_rec_cnt).DELIVER_TO_LOCATION;
                    lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_LOCATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).DELIVER_TO_LOCATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_PERSON_FULL_NAME   :=
                        lt_distributions_data (distributions_rec_cnt).DELIVER_TO_PERSON_FULL_NAME;
                    lt_po_distributions_type (ln_valid_rec_cnt).DELIVER_TO_PERSON_ID   :=
                        lt_distributions_data (distributions_rec_cnt).DELIVER_TO_PERSON_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_TYPE   :=
                        lt_distributions_data (distributions_rec_cnt).DESTINATION_TYPE;
                    lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_TYPE_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).DESTINATION_TYPE_CODE;
                    --lt_po_distributions_type(ln_valid_rec_cnt).DESTINATION_ORGANIZATION         :=    lt_distributions_data(distributions_rec_cnt).DESTINATION_ORGANIZATION    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_ORGANIZATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).DESTINATION_ORGANIZATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_SUBINVENTORY   :=
                        lt_distributions_data (distributions_rec_cnt).DESTINATION_SUBINVENTORY;
                    lt_po_distributions_type (ln_valid_rec_cnt).DESTINATION_CONTEXT   :=
                        lt_distributions_data (distributions_rec_cnt).DESTINATION_CONTEXT;
                    -- lt_po_distributions_type(ln_valid_rec_cnt).SET_OF_BOOKS                     :=    lt_distributions_data(distributions_rec_cnt).SET_OF_BOOKS    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).SET_OF_BOOKS_ID   :=
                        lt_distributions_data (distributions_rec_cnt).SET_OF_BOOKS_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).CHARGE_ACCOUNT   :=
                        lt_distributions_data (distributions_rec_cnt).CHARGE_ACCOUNT;
                    lt_po_distributions_type (ln_valid_rec_cnt).CHARGE_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).CHARGE_ACCOUNT_ID;
                    -- lt_po_distributions_type(ln_valid_rec_cnt).BUDGET_ACCOUNT                   :=    lt_distributions_data(distributions_rec_cnt).BUDGET_ACCOUNT    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).BUDGET_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).BUDGET_ACCOUNT_ID;
                    --lt_po_distributions_type(ln_valid_rec_cnt).ACCURAL_ACCOUNT                  :=    lt_distributions_data(distributions_rec_cnt).ACCURAL_ACCOUNT    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).ACCRUAL_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).ACCRUAL_ACCOUNT_ID;
                    --lt_po_distributions_type(ln_valid_rec_cnt).VARIANCE_ACCOUNT                 :=    lt_distributions_data(distributions_rec_cnt).VARIANCE_ACCOUNT    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).VARIANCE_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).VARIANCE_ACCOUNT_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).AMOUNT_BILLED   :=
                        lt_distributions_data (distributions_rec_cnt).AMOUNT_BILLED;
                    lt_po_distributions_type (ln_valid_rec_cnt).ACCRUE_ON_RECEIPT_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).ACCRUE_ON_RECEIPT_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).ACCRUED_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).ACCRUED_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).PREVENT_ENCUMBRANCE_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).PREVENT_ENCUMBRANCE_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).ENCUMBERED_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).ENCUMBERED_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).ENCUMBERED_AMOUNT   :=
                        lt_distributions_data (distributions_rec_cnt).ENCUMBERED_AMOUNT;
                    lt_po_distributions_type (ln_valid_rec_cnt).UNENCUMBERED_QUANTITY   :=
                        lt_distributions_data (distributions_rec_cnt).UNENCUMBERED_QUANTITY;
                    lt_po_distributions_type (ln_valid_rec_cnt).UNENCUMBERED_AMOUNT   :=
                        lt_distributions_data (distributions_rec_cnt).UNENCUMBERED_AMOUNT;
                    lt_po_distributions_type (ln_valid_rec_cnt).FAILED_FUNDS   :=
                        lt_distributions_data (distributions_rec_cnt).FAILED_FUNDS;
                    lt_po_distributions_type (ln_valid_rec_cnt).FAILED_FUNDS_LOOKUP_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).FAILED_FUNDS_LOOKUP_CODE;
                    lt_po_distributions_type (ln_valid_rec_cnt).GL_ENCUMBERED_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).GL_ENCUMBERED_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).GL_ENCUMBERED_PERIOD_NAME   :=
                        lt_distributions_data (distributions_rec_cnt).GL_ENCUMBERED_PERIOD_NAME;
                    lt_po_distributions_type (ln_valid_rec_cnt).GL_CANCELLED_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).GL_CANCELLED_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).GL_CLOSED_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).GL_CLOSED_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).REQ_HEADER_REFERENCE_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).REQ_HEADER_REFERENCE_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).REQ_LINE_REFERENCE_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).REQ_LINE_REFERENCE_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).REQ_DISTRIBUTION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).REQ_DISTRIBUTION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_ENTITY   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_ENTITY;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_ENTITY_ID   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_ENTITY_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_OPERATION_SEQ_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_OPERATION_SEQ_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_RESOURCE_SEQ_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_RESOURCE_SEQ_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_REPETITIVE_SCHEDULE   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_REPETITIVE_SCHEDULE;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_REPETITIVE_SCHEDULE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_REPETITIVE_SCHEDULE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_LINE_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_LINE_CODE;
                    lt_po_distributions_type (ln_valid_rec_cnt).WIP_LINE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).WIP_LINE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).BOM_RESOURCE_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).BOM_RESOURCE_CODE;
                    lt_po_distributions_type (ln_valid_rec_cnt).BOM_RESOURCE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).BOM_RESOURCE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).USSGL_TRANSACTION_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).USSGL_TRANSACTION_CODE;
                    lt_po_distributions_type (ln_valid_rec_cnt).GOVERNMENT_CONTEXT   :=
                        lt_distributions_data (distributions_rec_cnt).GOVERNMENT_CONTEXT;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROJECT   :=
                        lt_distributions_data (distributions_rec_cnt).PROJECT;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROJECT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PROJECT_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).TASK   :=
                        lt_distributions_data (distributions_rec_cnt).TASK;
                    lt_po_distributions_type (ln_valid_rec_cnt).TASK_ID   :=
                        lt_distributions_data (distributions_rec_cnt).TASK_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).END_ITEM_UNIT_NUMBER   :=
                        lt_distributions_data (distributions_rec_cnt).END_ITEM_UNIT_NUMBER;
                    lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE   :=
                        lt_distributions_data (distributions_rec_cnt).EXPENDITURE;
                    lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_TYPE   :=
                        lt_distributions_data (distributions_rec_cnt).EXPENDITURE_TYPE;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROJECT_ACCOUNTING_CONTEXT   :=
                        lt_distributions_data (distributions_rec_cnt).PROJECT_ACCOUNTING_CONTEXT;
                    lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION   :=
                        lt_distributions_data (distributions_rec_cnt).EXPENDITURE_ORGANIZATION;
                    lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_ORGANIZATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).EXPENDITURE_ORGANIZATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROJECT_RELEATED_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).PROJECT_RELEATED_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).EXPENDITURE_ITEM_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).EXPENDITURE_ITEM_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE_CATEGORY   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE_CATEGORY;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE1   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE1;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE2   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE2;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE3   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE3;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE4   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE4;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE5   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE5;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE6   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE6;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE7   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE7;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE8   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE8;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE9   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE9;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE10   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE10;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE11   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE11;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE12   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE12;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE13   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE13;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE14   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE14;
                    lt_po_distributions_type (ln_valid_rec_cnt).ATTRIBUTE15   :=
                        lt_distributions_data (distributions_rec_cnt).ATTRIBUTE15;
                    lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATE_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).LAST_UPDATE_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATED_BY   :=
                        lt_distributions_data (distributions_rec_cnt).LAST_UPDATED_BY;
                    lt_po_distributions_type (ln_valid_rec_cnt).LAST_UPDATE_LOGIN   :=
                        lt_distributions_data (distributions_rec_cnt).LAST_UPDATE_LOGIN;
                    lt_po_distributions_type (ln_valid_rec_cnt).CREATION_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).CREATION_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).CREATED_BY   :=
                        lt_distributions_data (distributions_rec_cnt).CREATED_BY;
                    lt_po_distributions_type (ln_valid_rec_cnt).REQUEST_ID   :=
                        gn_conc_request_id; --lt_distributions_data(distributions_rec_cnt).REQUEST_ID    ;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROGRAM_APPLICATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PROGRAM_APPLICATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROGRAM_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PROGRAM_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROGRAM_UPDATE_DATE   :=
                        lt_distributions_data (distributions_rec_cnt).PROGRAM_UPDATE_DATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).RECOVERABLE_TAX   :=
                        lt_distributions_data (distributions_rec_cnt).RECOVERABLE_TAX;
                    lt_po_distributions_type (ln_valid_rec_cnt).NONRECOVERABLE_TAX   :=
                        lt_distributions_data (distributions_rec_cnt).NONRECOVERABLE_TAX;
                    lt_po_distributions_type (ln_valid_rec_cnt).RECOVERY_RATE   :=
                        lt_distributions_data (distributions_rec_cnt).RECOVERY_RATE;
                    lt_po_distributions_type (ln_valid_rec_cnt).TAX_RECOVERY_OVERRIDE_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).TAX_RECOVERY_OVERRIDE_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).AWARD_ID   :=
                        lt_distributions_data (distributions_rec_cnt).AWARD_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_LINE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).OKE_CONTRACT_LINE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_LINE_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).OKE_CONTRACT_LINE_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_DELIVERABLE_ID   :=
                        lt_distributions_data (distributions_rec_cnt).OKE_CONTRACT_DELIVERABLE_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).OKE_CONTRACT_DELIVERABLE_NUM   :=
                        lt_distributions_data (distributions_rec_cnt).OKE_CONTRACT_DELIVERABLE_NUM;
                    lt_po_distributions_type (ln_valid_rec_cnt).AWARD_NUMBER   :=
                        lt_distributions_data (distributions_rec_cnt).AWARD_NUMBER;
                    lt_po_distributions_type (ln_valid_rec_cnt).AMOUNT_ORDERED   :=
                        lt_distributions_data (distributions_rec_cnt).AMOUNT_ORDERED;
                    lt_po_distributions_type (ln_valid_rec_cnt).INVOICE_ADJUSTMENT_FLAG   :=
                        lt_distributions_data (distributions_rec_cnt).INVOICE_ADJUSTMENT_FLAG;
                    lt_po_distributions_type (ln_valid_rec_cnt).DEST_CHARGE_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).DEST_CHARGE_ACCOUNT_ID;
                    --lt_po_distributions_type(ln_valid_rec_cnt).DEST_CHARGE_ACCOUNT            :=    lt_distributions_data(distributions_rec_cnt).DEST_CHARGE_ACCOUNT;
                    lt_po_distributions_type (ln_valid_rec_cnt).DEST_VARIANCE_ACCOUNT_ID   :=
                        lt_distributions_data (distributions_rec_cnt).DEST_VARIANCE_ACCOUNT_ID;
                    --lt_po_distributions_type(ln_valid_rec_cnt).DEST_VARIANCE_ACCOUNT          :=    lt_distributions_data(distributions_rec_cnt).DEST_VARIANCE_ACCOUNT;
                    lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_LINE_LOCATION_ID   :=
                        lt_distributions_data (distributions_rec_cnt).INTERFACE_LINE_LOCATION_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROCESSING_ID   :=
                        lt_distributions_data (distributions_rec_cnt).PROCESSING_ID;
                    lt_po_distributions_type (ln_valid_rec_cnt).PROCESS_CODE   :=
                        lt_distributions_data (distributions_rec_cnt).PROCESS_CODE;
                    lt_po_distributions_type (ln_valid_rec_cnt).INTERFACE_DISTRIBUTION_REF   :=
                        lt_distributions_data (distributions_rec_cnt).INTERFACE_DISTRIBUTION_REF;
                END LOOP;

                -------------------------------------------------------------------
                -- do a bulk insert into the XXD_PO_DISTRIBUTIONS_STG_T table
                ----------------------------------------------------------------
                write_log (
                    'Bulk Insert  in to list lines table XXD_PO_DISTRIBUTIONS_STG_T');

                FORALL ln_cnt IN 1 .. lt_po_distributions_type.COUNT
                  SAVE EXCEPTIONS
                    INSERT INTO XXD_PO_DISTRIBUTIONS_STG_T
                         VALUES lt_po_distributions_type (ln_cnt);
            END IF;

            COMMIT;
        END LOOP;

        IF c_get_distributions_rec%ISOPEN
        THEN
            CLOSE c_get_distributions_rec;
        END IF;

        x_rec_count        := ln_valid_rec_cnt;
    EXCEPTION
        WHEN ex_program_Exception
        THEN
            ROLLBACK TO INSERT_TABLE2;
            x_ret_code   := gn_err_const;

            IF c_get_distributions_rec%ISOPEN
            THEN
                CLOSE c_get_distributions_rec;
            END IF;

            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', -- SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --   SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'XXD_PO_DISTRIBUTIONS_STG_T', NULL
                                           , 'Exception in bulk insert');
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO INSERT_TABLE2;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_distributions_rec%ISOPEN
            THEN
                CLOSE c_get_distributions_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                write_log (
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
                xxd_common_utils.record_error (
                    'PO',
                    gn_org_id,
                    'XXD Open Purchase Orders Conversion Program',
                    --   SQLCODE,
                    SQLERRM,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --   SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'XXD_PO_DISTRIBUTIONS_STG_T',
                    NULL,
                    SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE));
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO INSERT_TABLE2;
            x_ret_code   := gn_err_const;
            write_log (
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_distributions_rec%ISOPEN
            THEN
                CLOSE c_get_distributions_rec;
            END IF;

            xxd_common_utils.record_error (
                'PO',
                gn_org_id,
                'XXD Open Purchase Orders Conversion Program',
                --    SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --   SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'XXD_PO_DISTRIBUTIONS_STG_T',
                NULL,
                'Unexpected Exception while inserting into XXD_PO_DISTRIBUTIONS_STG_T');
    END extract_po_distribution;


    PROCEDURE extract_po_1206_records (x_ret_code OUT VARCHAR2, x_return_mesg OUT VARCHAR2, p_org_name IN VARCHAR2
                                       , p_scenario IN VARCHAR2)
    AS
        lx_return_mesg    VARCHAR2 (2000);
        ln_header_cnt     NUMBER := 0;
        ln_lines_cnt      NUMBER := 0;
        ln_location_cnt   NUMBER := 0;
        ln_disti_cnt      NUMBER := 0;
        ln_line_cnt       NUMBER := 0;
    BEGIN
        --x_return_status:= 'P';
        -- Extract Open Purchase Order Header Records from 1206
        write_log (
            'Calling extract_po_headers Procedure to load the 1206 data to stage');
        extract_po_headers (x_ret_code      => x_ret_code,
                            x_rec_count     => ln_header_cnt,
                            p_org_name      => p_org_name,
                            p_scenario      => p_scenario,
                            x_return_mesg   => lx_return_mesg);

        write_log (
            'extract_po_headers Procedure Completed loading  1206 data to stage');

        --- Extract Open Purchase Order  Lines  Records from 1206
        write_log (
            'Calling extract_po_lines Procedure to load the 1206 data to stage');
        extract_po_lines (x_ret_code      => x_ret_code,
                          x_rec_count     => ln_line_cnt,
                          x_return_mesg   => lx_return_mesg);

        write_log (
            'extract_po_lines Procedure Completed  loading  1206 data to stage');

        --- Extract  Open Purchase Order line Location Records from 1206
        write_log (
            'Calling extract_po_line_locations Procedure to load the 1206 data to stage');
        /*   extract_po_line_locations     ( x_ret_code       =>  x_ret_code
                                         , x_rec_count      => ln_location_cnt
                                         , x_return_mesg    =>  lx_return_mesg
                                                                     ); */
        write_log (
            'extract_po_line_locations Procedure Completed  loading  1206 data to stage');

        --- Extract Price list qualifiers
        write_log (
            'Calling extract_po_distribution Procedure to load the 1206 data to stage');
        extract_po_distribution (x_ret_code      => x_ret_code,
                                 x_rec_count     => ln_disti_cnt,
                                 x_return_mesg   => lx_return_mesg);

        write_log (
            'extract_po_distribution Procedure Completed  loading  1206 data to stage ');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
            x_return_mesg   :=
                   'When others error When loading the data from 1206 '
                || SQLERRM;
            write_log (
                   'When others error while loading the data from 1206 => '
                || SQLERRM);
            xxd_common_utils.record_error ('PO', gn_org_id, 'XXD Open Purchase Orders Conversion Program', --      SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --    SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'extract_PO_1206_records', NULL
                                           , x_return_mesg);
    END extract_po_1206_records;



    FUNCTION update_site_stg
        RETURN VARCHAR2
    -- +===================================================================+
    -- | Name             :  UPDATE_SITE_STG                                           |
    -- | Description      :  This function will update the sites for the    |
    -- |                     MARUBENI CORPORATION', 'ITOCHU CORPORATION'    |
    -- |                     suppliers                                       |
    -- |                                                                   |
    -- | Parameters       :                                                      |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns          :  update status                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        CURSOR get_new_site_id IS
            --Commented by BT Technology Team on 04-May-2015 for site updation of MARUBENI and ITOCHU
            /*SELECT DISTINCT flv.attribute1 new_site_code, hdr.po_header_id
              FROM XXD_PO_LINES_STG_T line,
                   XXD_PO_HEADERS_STG_T hdr,
                   fnd_lookup_values flv
             WHERE     hdr.po_header_id = line.po_header_id
                   AND lookup_type LIKE 'XXD_1206_INV_ORG_MAPPING'
                   AND line.ship_from_organization_code != 'IMC'
                   AND flv.meaning = line.ship_from_organization_code
                   AND hdr.vendor_name IN
                          ('MARUBENI CORPORATION', 'ITOCHU CORPORATION')
                   AND LANGUAGE = USERENV ('LANG');*/



            --Added by BT Technology Team on 04-May-2015 for site updation of MARUBENI and ITOCHU
            SELECT DISTINCT flv.attribute1 new_site_code, hdr.po_header_id
              FROM XXD_PO_LINES_STG_T line, XXD_PO_HEADERS_STG_T hdr, XXD_1206_OE_ORDER_LINES_ALL xool,
                   fnd_lookup_values flv
             WHERE     hdr.po_header_id = line.po_header_id
                   AND line.line_attribute5 = xool.line_id --see the warehouse present with this Line ID , match it with old Lookup value and get the new value
                   AND lookup_type LIKE 'XXD_1206_INV_ORG_MAPPING'
                   AND flv.meaning != 'IMC'
                   AND flv.lookup_code = xool.ship_from_org_id
                   AND hdr.vendor_name IN
                           ('MARUBENI CORPORATION', 'ITOCHU CORPORATION')
                   AND LANGUAGE = USERENV ('LANG');
    BEGIN
        DELETE XXD_PO_LINES_STG_T
         WHERE line_attribute5 IS NULL;             --Commented on 10-Aug-2015

        FOR rec_new_site_id IN get_new_site_id
        LOOP
            BEGIN
                UPDATE XXD_PO_HEADERS_STG_T
                   SET vendor_site_code   = rec_new_site_id.new_site_code
                 --attribute11 = ''                                    --Updating GTN Flag as NULL for Marubeni by BT Technology Team on 04-May-2015
                 WHERE po_header_id = rec_new_site_id.po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE XXD_PO_HEADERS_STG_T
                       SET error_message1 = 'Error occured while updating site details for marubeni and itochu suppliers', RECORD_STATUS = gc_error_status
                     WHERE po_header_id = rec_new_site_id.po_header_id;
            END;
        END LOOP;

        COMMIT;
        RETURN 'Y';
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE open_po_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_org_name IN VARCHAR2, p_scenario IN VARCHAR2, p_action IN VARCHAR2, p_batch_cnt IN NUMBER
                            ,                  --  ,p_batch_size     IN NUMBER
                              p_debug IN VARCHAR2 DEFAULT 'N')
    -- +===================================================================+
    -- | Name  : OPEN_PO_MAIN                                              |
    -- | Description      : This is the main procedure which will call     |
    -- |                    the child program to validate and populate the |
    -- |                        data into oracle purchase order base tables|
    -- |                                                                   |
    -- | Parameters : p_action, p_batch_size, p_debug, pa_batch_size       |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :   x_errbuf, x_retcode                                   |
    -- |                                                                   |
    -- +===================================================================+
    IS
        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id        hdr_batch_id_t;
        lc_conlc_status        VARCHAR2 (150);
        ln_request_id          NUMBER := 0;
        lc_phase               VARCHAR2 (200);
        lc_status              VARCHAR2 (200);
        lc_dev_phase           VARCHAR2 (200);
        lc_dev_status          VARCHAR2 (200);
        lc_message             VARCHAR2 (200);
        ln_ret_code            NUMBER;
        lc_err_buff            VARCHAR2 (1000);
        ln_count               NUMBER;
        ln_cntr                NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                BOOLEAN;
        lx_return_mesg         VARCHAR2 (2000);
        ln_valid_rec_cnt       NUMBER;



        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id               request_table;

        CURSOR get_org_batch_c IS
            SELECT DISTINCT org_id, batch_id
              FROM po_headers_interface phi
             WHERE     NOT EXISTS
                           (SELECT 1
                              FROM po_headers_all pha
                             WHERE     phi.org_id = pha.org_id
                                   AND pha.segment1 = phi.document_num)
                   AND PROCESS_CODE IS NULL;

        ln_org_id              NUMBER;
        ln_batch_id            NUMBER;


        ln_counter             NUMBER;

        CURSOR cur_update_edi IS
            SELECT                                                  --DISTINCT
                   pha.po_header_id, STG.EDI_PROCESSED_FLAG, STG.EDI_PROCESSED_STATUS
              FROM PO_HEADERS_ALL PHA, --HR_OPERATING_UNITS HOU,
                                       XXD_PO_HEADERS_STG_T STG
             WHERE     pha.org_id = stg.orgs_id
                   AND stg.PO_NUMBER = pha.segment1
                   AND stg.po_header_id = pha.attribute15; --as Old PO Header ID is stored in attribute15 on 12.2.3 po headers all.

        --  FOR UPDATE OF pha.EDI_PROCESSED_FLAG, pha.EDI_PROCESSED_STATUS;  --Commented on 11-Aug-2015


        TYPE l_edi_upd_tab IS TABLE OF cur_update_edi%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_edi_header           l_edi_upd_tab;



        /*      TYPE request_table1 IS TABLE OF NUMBER
                                       INDEX BY BINARY_INTEGER;

              l_req_id1               request_table1; */

        --ln_request_id          NUMBER;
        ln_loop_counter        NUMBER := 1;
        gc_code_pointer        VARCHAR2 (500);
        lb_wait_for_request    BOOLEAN;
        site_updation_status   VARCHAR2 (20); --Added by BT Technology team on 04-May-2015
    BEGIN
        errbuf               := NULL;
        retcode              := 0;
        gc_debug_flag        := p_debug;
        gn_conc_request_id   := ln_parent_request_id;


        FND_FILE.PUT_LINE (fnd_file.LOG,
                           'p_org_name         =>           ' || p_org_name);

        FND_FILE.PUT_LINE (fnd_file.LOG,
                           'p_action           =>           ' || p_action);
        FND_FILE.PUT_LINE (fnd_file.LOG,
                           'p_batch_cnt        =>           ' || p_batch_cnt);
        --FND_FILE.PUT_LINE (fnd_file.LOG, 'p_batch_size       =>           ' || p_batch_size);
        FND_FILE.PUT_LINE (
            fnd_file.LOG,
            'Debug              =>           ' || gc_debug_flag);



        IF p_action = gc_extract_only
        THEN
            Write_log ('Truncate stage table Start');
            --truncate stage tables before extract from 1206
            truncte_stage_tables (x_ret_code      => retcode,
                                  x_return_mesg   => lx_return_mesg,
                                  p_scenario      => p_scenario); --Added on 26-June-2015
            write_log ('Truncate stage table End');
            --- extract 1206 Open Purchase Orders data to stage
            write_log ('Extract stage table from 1206 Start');
            extract_po_1206_records (x_ret_code => retcode, x_return_mesg => lx_return_mesg, p_org_name => p_org_name
                                     , p_scenario => p_scenario);


            IF     p_org_name = 'Deckers Japan OU'
               AND p_scenario = 'Japan PO Source from FACTORY' --Added on 20-Nov-2015 Not to call vendor site updation in case of Non-Factory japan scenario
            THEN
                write_log ('Updating sites in staging table');
                site_updation_status   := update_site_stg;

                IF site_updation_status = 'Y'
                THEN
                    write_log ('Site updation successful');
                ELSE
                    write_log ('Site updation not successful');
                END IF;
            END IF;


            DELETE XXD_PO_HEADERS_STG_T
             WHERE po_header_id NOT IN
                       (SELECT po_header_id FROM XXD_PO_LINES_STG_T);

            DELETE XXD_PO_DISTRIBUTIONS_STG_T
             WHERE po_line_id NOT IN
                       (SELECT po_line_id FROM XXD_PO_LINES_STG_T);

            COMMIT;


            write_log ('Extract stage table from 1206 End');
        ELSIF p_action = gc_validate_only
        THEN
            --DELETE XXD_PO_HEADERS_STG_T WHERE po_header_id NOT IN (SELECT po_header_id FROM XXD_PO_LINES_STG_T);

            --         COMMIT;

            --get_1206_org_id (p_org_name =>  p_org_name, x_org_id => lx_org_id) ;

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_PO_HEADERS_STG_T
             WHERE     batch_id IS NULL
                   AND RECORD_STATUS IN (gc_new_status, gc_error_status)
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                                   AND attribute1 = p_org_name
                                   AND TO_NUMBER (LOOKUP_CODE) = org_id
                                   AND language = 'US');

            write_log ('Creating Batch id and update  XXD_PO_HEADERS_STG_T');

            -- Create batches of records and assign batch id
            FOR i IN 1 .. p_batch_cnt
            LOOP
                /* BEGIN
                    SELECT XXD_PO_OPENCONV_BATCH_STG_S.NEXTVAL INTO ln_hdr_batch_id (i) FROM DUAL;

                    write_log ('ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                 END;
                 */

                SELECT XXD_PO_OPENCONV_BATCH_STG_S.NEXTVAL
                  INTO ln_hdr_batch_id (i)
                  FROM DUAL;

                write_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                write_log (
                       'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                    || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                UPDATE XXD_PO_HEADERS_STG_T
                   SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id
                 WHERE     batch_id IS NULL
                       AND ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_cnt)
                       AND RECORD_STATUS IN (gc_new_status, gc_error_status)
                       AND EXISTS
                               (SELECT 1
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_1206_OU_MAPPING'
                                       AND attribute1 = p_org_name
                                       AND TO_NUMBER (LOOKUP_CODE) = org_id
                                       AND language = 'US');
            END LOOP;

            write_log (
                'completed updating Batch id in  XXD_PO_HEADERS_STG_T');
        ELSIF p_action = gc_load_only
        THEN
            write_log (
                'Fetching batch id from XXD_PO_HEADERS_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR I
                IN (SELECT DISTINCT batch_id
                      FROM XXD_PO_HEADERS_STG_T
                     WHERE     batch_id IS NOT NULL
                           AND RECORD_STATUS = gc_validate_status
                           AND EXISTS
                                   (SELECT 1
                                      FROM fnd_lookup_values
                                     WHERE     lookup_type =
                                               'XXD_1206_OU_MAPPING'
                                           AND attribute1 = p_org_name
                                           AND TO_NUMBER (LOOKUP_CODE) =
                                               org_id
                                           AND language = 'US'))
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;
        ELSIF p_action = 'SUBMIT'
        THEN
            ln_org_id     := NULL;
            ln_batch_id   := NULL;

            OPEN get_org_batch_c;

            LOOP
                ln_org_id   := NULL;

                FETCH get_org_batch_c INTO ln_org_id, ln_batch_id;

                EXIT WHEN get_org_batch_c%NOTFOUND;


                --fnd_global.APPS_INITIALIZE (0, 50721, 201);

                --fnd_file.put_line (fnd_file.LOG, 'Org id ' || ln_org_id);


                --fnd_global.APPS_INITIALIZE (l_user_id, l_resp_id, l_appl_id);
                MO_GLOBAL.init ('PO');
                mo_global.set_policy_context ('S', ln_org_id);
                FND_REQUEST.SET_ORG_ID (ln_org_id);
                DBMS_APPLICATION_INFO.set_client_info (ln_org_id);

                /*ln_request_id :=
                   fnd_request.submit_request (
                      application   => gc_appl_shrt_name,
                      program       => gc_program_shrt_name,
                      description   => NULL,
                      start_time    => NULL,
                      sub_request   => FALSE,
                      argument1     => NULL,
                      argument2     => gc_standard_type,
                      argument3     => NULL,
                      argument4     => gc_update_create,
                      argument5     => NULL,
                      argument6     => gc_approved,
                      argument7     => NULL,
                      argument8     => ln_batch_id,
                      argument9     => ln_org_id,
                      argument10    => NULL,
                      argument11    => NULL,
                      argument12    => NULL,
                      argument13    => NULL,
                      argument14    => NULL,
                      argument15    => NULL,
                      argument16    => NULL,
                      argument17    => NULL,
                      argument18    => 'Y');*/

                ln_request_id   :=
                    fnd_request.submit_request (
                        application   => gc_appl_shrt_name,
                        program       => gc_program_shrt_name,
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => FALSE,
                        argument1     => NULL,
                        argument2     => gc_standard_type,
                        argument3     => NULL,
                        argument4     => gc_update_create,
                        argument5     => NULL,
                        argument6     => gc_approved,
                        argument7     => NULL,
                        argument8     => ln_batch_id,
                        argument9     => ln_org_id,
                        argument10    => 'N',
                        argument11    => NULL,
                        argument12    => NULL,
                        argument13    => 'Y');

                COMMIT;


                IF ln_request_id > 0
                THEN
                    COMMIT;
                    l_req_id (ln_loop_counter)   := ln_request_id;
                    ln_loop_counter              := ln_loop_counter + 1;
                /*  ELSE
                     ROLLBACK; */
                END IF;
            END LOOP;

            CLOSE get_org_batch_c;

            --fnd_file.put_line (fnd_file.LOG, 'Test4');


            gc_code_pointer   :=
                'Waiting for child requests in PO Import process  ';

            IF l_req_id.COUNT > 0
            THEN
                --Waits for the Child requests completion
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    BEGIN
                        IF l_req_id (rec) IS NOT NULL
                        THEN
                            LOOP
                                lc_dev_phase    := NULL;
                                lc_dev_status   := NULL;


                                gc_code_pointer   :=
                                    'Calling fnd_concurrent.wait_for_request in PO Import process  ';

                                lb_wait_for_request   :=
                                    fnd_concurrent.wait_for_request (
                                        request_id   => l_req_id (rec),
                                        interval     => 1,
                                        max_wait     => 1,
                                        phase        => lc_phase,
                                        status       => lc_status,
                                        dev_phase    => lc_dev_phase,
                                        dev_status   => lc_dev_status,
                                        MESSAGE      => lc_message);

                                IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                                THEN
                                    EXIT;
                                END IF;
                            END LOOP;
                        /*ELSE
                           RAISE request_submission_failed; */

                        ------Start of adding changes by BT Technology Team on 16-Jul-2015---
                        /*BEGIN

                        OPEN cur_update_edi;

                        LOOP


                               FETCH cur_update_edi
                               BULK COLLECT INTO l_edi_header
                               LIMIT 100;

                               EXIT WHEN l_edi_header.COUNT = 0;

                              FORALL i IN l_edi_header.FIRST .. l_edi_header.LAST
                                   UPDATE po_headers_all
                                      SET EDI_PROCESSED_FLAG = l_edi_header (i).EDI_PROCESSED_FLAG,
                                          EDI_PROCESSED_STATUS = l_edi_header (i).EDI_PROCESSED_STATUS
                                    WHERE po_header_id = l_edi_header (i).po_header_id;

                       COMMIT;
                       END LOOP;
                             EXCEPTION WHEN OTHERS THEN
                               fnd_file.put_line (fnd_file.LOG,
                                                             'Error message while Updating EDI Flags ' || SUBSTR (SQLERRM, 1, 240));

                       END;      */

                        ------End of adding changes by BT Technology Team on 16-Jul-2015---
                        END IF;
                    EXCEPTION
                        /*    WHEN request_submission_failed
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Child Concurrent request submission failed - '
                                  || ' XXD_AP_INV_CONV_VAL_WORK - '
                                  || ln_request_id
                                  || ' - '
                                  || SQLERRM);
                            WHEN request_completion_abnormal
                            THEN
                               print_log_prc (
                                  p_debug,
                                     'Submitted request completed with error'
                                  || ' XXD_AP_INVOICE_CONV_VAL_WORK - '
                                  || ln_request_id); */
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Code pointer ' || gc_code_pointer);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error message ' || SUBSTR (SQLERRM, 1, 240));
                    END;
                END LOOP;
            END IF;

            ------Start of adding changes by BT Technology Team on 16-Jul-2015---
            BEGIN
                OPEN cur_update_edi;

                LOOP
                    FETCH cur_update_edi
                        BULK COLLECT INTO l_edi_header
                        LIMIT 100;

                    EXIT WHEN l_edi_header.COUNT = 0;

                    FORALL i IN l_edi_header.FIRST .. l_edi_header.LAST
                        UPDATE po_headers_all
                           SET EDI_PROCESSED_FLAG = l_edi_header (i).EDI_PROCESSED_FLAG, EDI_PROCESSED_STATUS = l_edi_header (i).EDI_PROCESSED_STATUS
                         WHERE po_header_id = l_edi_header (i).po_header_id;

                    COMMIT;
                END LOOP;

                CLOSE cur_update_edi;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error message while Updating EDI Flags '
                        || SUBSTR (SQLERRM, 1, 240));
            END;
        ------End of adding changes by BT Technology Team on 16-Jul-2015---
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            write_log (
                   'Calling XXDOPENPOCONVERSIONCHILD in batch '
                || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_PO_HEADERS_STG_T
                 WHERE batch_id = ln_hdr_batch_id (i);

                fnd_file.put_line (fnd_file.LOG, 'ln_cntr ' || ln_cntr);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        write_log (
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDO',
                                --'XXDCONV',
                                'XXDOPENPOCONVERSIONCHILD',
                                '',
                                '',
                                FALSE,
                                p_org_name,
                                p_debug,
                                p_action,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id);
                        write_log ('v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            write_log (
                                   'Calling WAIT FOR REQUEST XXDOPENPOCONVERSIONCHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            write_log (
                                   'Calling WAIT FOR REQUEST XXDOPENPOCONVERSIONCHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            write_log (
                   'Calling XXDOPENPOCONVERSIONCHILD in batch '
                || ln_hdr_batch_id.COUNT);
            write_log (
                'Calling WAIT FOR REQUEST XXDOPENPOCONVERSIONCHILD to complete');

            IF l_req_id.COUNT > 0
            THEN
                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait         :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                                  ,
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END LOOP;
            END IF;
        END IF;


        IF p_action = gc_validate_only
        THEN
            UPDATE XXD_PO_DISTRIBUTIONS_STG_T
               SET RECORD_STATUS   = 'V'
             WHERE po_line_id IN (SELECT po_line_id
                                    FROM XXD_PO_LINES_STG_T
                                   WHERE record_status = 'V');

            UPDATE XXD_PO_DISTRIBUTIONS_STG_T
               SET RECORD_STATUS   = 'E'
             WHERE po_line_id IN (SELECT po_line_id
                                    FROM XXD_PO_LINES_STG_T
                                   WHERE record_status = 'E');
        END IF;



        print_processing_summary (p_action => p_action, x_ret_code => retcode);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            write_log ('Error in Main Procedure' || SQLERRM);
    END open_po_main;

    PROCEDURE open_po_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_batch_id IN NUMBER
                             , p_parent_request_id IN NUMBER)
    AS
        CURSOR get_org_id_c IS
            SELECT DISTINCT org_id
              FROM po_headers_interface
             WHERE batch_id = p_batch_id;

        ln_org_id                   NUMBER;

        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.NAME%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        lc_create_reciprocal_flag   VARCHAR2 (1) := gc_no_flag;
        --ln_request_id             NUMBER                     := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        ln_ret_code                 NUMBER;
        lc_err_buff                 VARCHAR2 (1000);
        ln_count                    NUMBER;
        ln_submit_openpo            VARCHAR2 (50);
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.USER_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        /* BEGIN
            fnd_client_info.set_org_context (fnd_profile.VALUE ('ORG_ID'));
            mo_global.set_policy_context ('S', fnd_profile.VALUE ('ORG_ID'));
            COMMIT;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               NULL;
            WHEN OTHERS
            THEN
               NULL;
         END;
         */

        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_id);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.put_line (
            fnd_file.LOG,
            '**********      Open Purchase Order Validate/Import Program     ********** ');
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        write_log (
            '+---------------------------------------------------------------------------+');
        write_log (
            '******** START of Open Purchase Order Import Program ******');
        write_log (
            '+---------------------------------------------------------------------------+');


        IF p_action = gc_validate_only
        THEN
            write_log ('Calling validate_open_po :');
            validate_open_po (p_debug => p_debug_flag, p_batch_id => p_batch_id, p_process_mode => gc_validate_only
                              , p_request_id => p_parent_request_id);
        -- ,x_return_flag        =>           x_return_flag);

        ELSIF p_action = gc_load_only
        THEN
            write_log ('Calling transfer_po_header_records :');
            transfer_po_header_records (p_batch_id   => p_batch_id,
                                        x_ret_code   => retcode);
            --         IF retcode = gn_suc_const THEN
            ----           UPDATE po_headers_interface SET FROM_HEADER_ID = NULL where batch_id = p_batch_id;
            --           COMMIT;

            fnd_file.put_line (fnd_file.LOG, 'test3');
        /* OPEN get_org_id_c;

         LOOP
            FETCH get_org_id_c INTO ln_org_id;

            EXIT WHEN get_org_id_c%NOTFOUND;

            fnd_file.put_line (fnd_file.LOG, 'Test1');

            SUBMIT_PO_REQUEST (p_batch_id        => p_batch_id,
                               p_org_id          => ln_org_id,
                               p_submit_openpo   => ln_submit_openpo);
         END LOOP;

         CLOSE get_org_id_c; */
        --           SUBMIT_PO_REQUEST(p_batch_id =>  p_batch_id,p_submit_openpo =>ln_submit_openpo );
        --         END IF;
        END IF;
    --      ELSIF p_action = 'VALIDATE AND LOAD'
    --      THEN
    --         NULL;
    --      END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'test4');
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During open_po_child  Program');
            fnd_file.put_line (fnd_file.LOG, 'test5');
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'test6');
    END open_po_child;
END XXD_PO_OPENPOCNV_PKG;
/
