--
-- XXD_ITEM_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ITEM_CONV_PKG"
AS
    /****************************************************************************************/
    /* PACKAGE NAME:  XXD_ITEM_CONV_PKG                                                     */
    /*                                                                                      */
    /* PROGRAM NAME:  XXD INV Item Conversion - Worker Load Program,                        */
    /*         XXD INV Item Conversion - Worker Validate Program,                           */
    /*        XXD INV Item Conversion - Extract Program,                                    */
    /*        XXD INV Item Conversion - Validate and Load Program                           */
    /*                                                                                      */
    /* DEPENDENCIES:  XXD_common_utils                                                      */
    /*                                                                                      */
    /* REFERENCED BY: N/A                                                                   */
    /*                                                                                      */
    /* DESCRIPTION:   Item Conversion for R12 Data Migration                                */
    /*                                                                                      */
    /* HISTORY:                                                                             */
    /*--------------------------------------------------------------------------------------*/
    /* No     Developer       Date      Description                                         */
    /*                                                                                      */
    /*--------------------------------------------------------------------------------------*/
    /* 1.00     Ramya    13-JUN-2014  Package Body script for  Item Conversion.             */
    /* 1.01     Sryeruv  29-Sep-2014  Changed the code combination logic                    */
    /* 1.02    Srinivas K  05-Oct-2015 Modified                                                                           */
    /****************************************************************************************/
    --global variables
    lv_conc_request_id   NUMBER := fnd_global.conc_request_id;
    ln_user_id           NUMBER := fnd_profile.VALUE ('USER_ID');
    g_debug              VARCHAR2 (1);
    gn_org_id            NUMBER := FND_PROFILE.VALUE ('ORG_ID');
    gn_user_id           NUMBER := FND_PROFILE.VALUE ('USER_ID');
    gc_program_name      VARCHAR2 (100)
        := 'Deckers Item Organization assigment Program ';
    gn_request_id        NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gc_debug_flag        VARCHAR2 (1) := 'Y';

    /*+==========================================================================+
    | Procedure name                                                             |
    |     print_log                                                           |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Print log messages                             |
    +===========================================================================*/
    PROCEDURE print_log (p_message VARCHAR2)
    AS
    BEGIN
        IF (1 = 1)                                           --(g_debug = 'Y')
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END;


    PROCEDURE prt_log (p_debug VARCHAR2, p_message VARCHAR2)
    AS
    BEGIN
        IF p_debug = 'Y'                                     --(g_debug = 'Y')
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END;


    /*+==========================================================================+
    | Procedure name                                                             |
    |     min_max_batch_prc                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    |         Procedure min_max_batch_prc retrieives the Minimum              |
    |             and Maximum Batch Number.                         |
    +===========================================================================*/
    PROCEDURE min_max_batch_prc (x_low_batch_limit    OUT NUMBER,
                                 x_high_batch_limit   OUT NUMBER)
    IS
    BEGIN
        --print_log ('Procedure min_max_batch_prc');

        SELECT MIN (batch_number), MAX (batch_number)
          INTO x_low_batch_limit, x_high_batch_limit
          FROM xxd_item_conv_stg_t;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'OTHERS Exception in the Procedure Min_Max_Batch_Prc: '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                ln_user_id,
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure Min_Max_Batch_Prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     get_master_org_prc                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    |    Procedure get_master_org_prc retrieves Master organization code for the |
    |    organization code passed as Parameter.                       |
    +===========================================================================*/
    PROCEDURE get_master_org_prc (p_organization_code IN VARCHAR2, x_organization_code OUT VARCHAR2, x_m_organization_code OUT VARCHAR2)
    IS
    BEGIN
        SELECT organization_code,
               (SELECT organization_code
                  FROM mtl_parameters
                 WHERE organization_id = mp.master_organization_id) master_organization_code
          INTO x_organization_code, x_m_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_code = p_organization_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'OTHERS Exception in the Procedure Get_Master_Org_Prc:  '
                || SUBSTR (SQLERRM, 1, 499));
    END;

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
    PROCEDURE get_org_id_1206 (p_org_name   IN            VARCHAR2 -- New inv_org_name
                                                                  ,
                               x_org_id        OUT NOCOPY NUMBER) -- old inv_org_id (Based on the old name conter to new name)
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
    BEGIN
        --          px_meaning := p_org_name;
        --          apps.XXD_COMMON_UTILS.get_mapping_value (
        --          p_lookup_type    =>       'XXD_1206_INV_ORG_MAPPING',           -- Lookup type for mapping
        --          px_lookup_code   =>      px_lookup_code,
        --                                    -- Would generally be id of 12.0.6. eg: org_id
        --          px_meaning       =>      px_meaning,       -- internal name of old entity
        --          px_description   =>      px_description   ,            -- name of the old entity
        --          x_attribute1     =>      x_attribute1,    -- corresponding new 12.2.3 value
        --          x_attribute2     =>      x_attribute2,
        --          x_error_code     =>      x_error_code,
        --          x_error_msg      =>      x_error_msg
        --       );
        SELECT flv.meaning, flv.description, flv.attribute1,
               flv.attribute2, lookup_code
          INTO px_meaning, px_description, x_attribute1, x_attribute2,
                         x_org_id
          FROM fnd_lookup_values flv
         WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
               --AND lookup_code = 'XXD_1206_INV_ORG_MAPPING'
               AND flv.attribute1 = p_org_name
               AND LANGUAGE = 'US'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                               AND NVL (end_date_active, SYSDATE + 1)
               AND ROWNUM = 1;
    --       SELECT organization_id
    --          INTO x_org_id
    --          FROM hr_operating_units
    --         WHERE UPPER (NAME) = UPPER (x_attribute1);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                px_meaning   := p_org_name;
                apps.xxd_common_utils.get_mapping_value (
                    p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING',
                    -- Lookup type for mapping
                    px_lookup_code   => px_lookup_code,
                    -- Would generally be id of 12.0.6. eg: org_id
                    px_meaning       => px_meaning,
                    -- internal name of old entity
                    px_description   => px_description,
                    -- name of the old entity
                    x_attribute1     => x_attribute1,
                    -- corresponding new 12.2.3 value
                    x_attribute2     => x_attribute2,
                    x_error_code     => x_error_code,
                    x_error_msg      => x_error_msg);
                x_org_id     := px_lookup_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    print_log (
                        'Exception to GET_ORG_ID Procedure' || SQLERRM);
            END;
        WHEN OTHERS
        THEN
            print_log ('Exception to GET_ORG_ID Procedure' || SQLERRM);
    END get_org_id_1206;

    /*+==========================================================================+
    | Function name                                                              |
    |     calc_eligible_records                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    | Function calc_eligible_records identifies the number of records eligible   |
    | for the conversion process.                                                |
    +===========================================================================*/
    FUNCTION calc_eligible_records (p_organization_code IN VARCHAR2)
        RETURN NUMBER
    IS
        l_organization_id    NUMBER;
        l_eligible_rec_cnt   NUMBER;
    BEGIN
        --GET_ORG_ID_1206(p_organization_code, l_organization_id);
        SELECT organization_id
          INTO l_organization_id
          FROM mtl_parameters
         WHERE organization_code = p_organization_code;

        UPDATE xxd_item_conv_stg_t
           SET organization_id   = l_organization_id
         WHERE     organization_code = p_organization_code
               AND record_status = 'N';

        SELECT COUNT (1)
          INTO l_eligible_rec_cnt
          FROM xxd_item_conv_stg_t x
         WHERE     x.organization_id =
                   NVL (l_organization_id, x.organization_id)
               AND x.record_status IN ('N', 'E');

        print_log (
               'Inside calc_eligible_records - the no of eligible records are $l_eligible_rec_cnt$ = '
            || l_eligible_rec_cnt);
        RETURN l_eligible_rec_cnt;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'OTHERS Exception in the Function Calc_Eligible_Records:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Function Calc_Eligible_Records.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END;

    /*+==========================================================================+
    | Function name                                                              |
    |     get_record_count                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    | Function get_record_count calculates the count of the records based        |
    | on the Organization code and record_status passed as paramters,If no          |
    | parameters are passed, the total record count will be retrieved.         |
    +===========================================================================*/
    FUNCTION get_record_count (p_organization_code IN VARCHAR2, p_batch_number IN NUMBER, p_record_status IN VARCHAR2)
        RETURN NUMBER
    IS
        l_record_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_record_count
          FROM xxd_item_conv_stg_t x
         WHERE     x.organization_code =
                   NVL (p_organization_code, x.organization_code)
               AND x.batch_number = p_batch_number
               AND x.record_status = NVL (p_record_status, x.record_status);

        RETURN l_record_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'OTHERS Exception in the Function Get_Record_Count:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Worker Validate Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Function Get_Record_Count.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     submit_child_requests                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    | Procedure submit_child_requests submits the child requests 'n'          |
    | number of times based on no of batches created for the records.         |
    | This procedure is common for submitting the child programs              |
    | related to both Validation and Load.                         |
    +===========================================================================*/
    PROCEDURE submit_child_requests (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_organization_code IN VARCHAR2, p_appln_shrt_name IN VARCHAR2, p_conc_pgm_name IN VARCHAR2, p_batch_low_limit IN NUMBER
                                     , p_batch_high_limit IN NUMBER)
    IS
        --Variable declarations
        l_batch_nos          VARCHAR2 (1000);
        l_sub_requests       fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt    NUMBER;
        l_warning_cnt        NUMBER := 0;
        l_error_cnt          NUMBER := 0;
        l_return             BOOLEAN;
        l_phase              VARCHAR2 (30);
        l_status             VARCHAR2 (30);
        l_dev_phase          VARCHAR2 (30);
        l_dev_status         VARCHAR2 (30);
        l_message            VARCHAR2 (1000);
        l_request_id         NUMBER;
        ln_count             NUMBER := 0;
        ln_organization_id   NUMBER;

        --Cursor for Distinct Batch Number,organization_code
        CURSOR get_batch_org (p_org_id NUMBER)
        IS
              SELECT batch_number, organization_code
                FROM xxd_item_conv_stg_t
               WHERE     batch_number BETWEEN p_batch_low_limit
                                          AND p_batch_high_limit
                     AND organization_id = NVL (p_org_id, organization_id)
            GROUP BY batch_number, organization_code
            ORDER BY batch_number;
    BEGIN
        get_org_id_1206 (p_org_name   => p_organization_code -- New inv_org_name
                                                            ,
                         x_org_id     => ln_organization_id);
        print_log (
               'p_organization_code = '
            || p_organization_code
            || ' ln_organization_id '
            || ln_organization_id);

        FOR c1_rec IN get_batch_org (ln_organization_id)
        LOOP
            print_log (
                   ' c1_rec.batch_number = '
                || c1_rec.batch_number
                || ' c1_rec.organization_code '
                || c1_rec.organization_code);
            l_request_id   :=
                fnd_request.submit_request (
                    application   => p_appln_shrt_name,
                    --Submitting Child Requests
                    program       => p_conc_pgm_name,
                    argument1     => c1_rec.organization_code,
                    argument2     => c1_rec.batch_number,
                    argument3     => c1_rec.batch_number);
            print_log (' batch_number :' || c1_rec.batch_number);
        END LOOP;

        COMMIT;
        print_log (' End Time :' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
        print_log (' lv_conc_request_id :' || lv_conc_request_id);
        l_sub_requests   :=
            fnd_concurrent.get_sub_requests (lv_conc_request_id);
        ln_count   := l_sub_requests.COUNT;
        print_log (
               'Waiting for child requests to be completed.:ln_count'
            || ln_count);

        IF ln_count > 0
        THEN
            FOR i IN l_sub_requests.FIRST .. l_sub_requests.LAST
            LOOP
                print_log ('In Loop.:');
                print_log ('request_id : ' || l_sub_requests (i).request_id);
                print_log ('phase : ' || l_sub_requests (i).phase);
                print_log ('status :' || l_sub_requests (i).status);
                print_log ('dev_phase :' || l_sub_requests (i).dev_phase);
                print_log ('dev_status :' || l_sub_requests (i).dev_status);
                print_log ('message :' || l_sub_requests (i).MESSAGE);

                IF NVL (l_sub_requests (i).request_id, 0) > 0
                THEN
                    LOOP
                        l_return   :=
                            fnd_concurrent.wait_for_request (
                                l_sub_requests (i).request_id,
                                --Waiting for Child Requests to be completed.
                                10,
                                60,
                                l_sub_requests (i).phase,
                                l_sub_requests (i).status,
                                l_sub_requests (i).dev_phase,
                                l_sub_requests (i).dev_status,
                                l_sub_requests (i).MESSAGE);
                        COMMIT;

                        --Count of records ended in warning.
                        IF UPPER (l_sub_requests (i).status) = 'WARNING'
                        THEN
                            l_warning_cnt   := l_warning_cnt + 1;
                        END IF;

                        --Count of records ended in error.
                        IF UPPER (l_sub_requests (i).status) = 'ERROR'
                        THEN
                            l_error_cnt   := l_error_cnt + 1;
                        END IF;

                        EXIT WHEN    UPPER (l_sub_requests (i).phase) =
                                     'COMPLETED'
                                  OR UPPER (l_sub_requests (i).status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;
                END IF;
            END LOOP;
        END IF;

        print_log ('Checking for the errored Batch Numbers.');

        FOR c1_rec IN get_batch_org (ln_organization_id)
        LOOP
            l_errored_rec_cnt   :=
                get_record_count (
                    p_organization_code   => c1_rec.organization_code,
                    --Get the errored record count
                    p_batch_number        => c1_rec.batch_number,
                    p_record_status       => 'E');

            IF l_errored_rec_cnt > 0
            THEN
                l_batch_nos   := l_batch_nos || ',' || c1_rec.batch_number;
            END IF;
        END LOOP;

        IF l_warning_cnt > 0
        THEN
            l_batch_nos   := TRIM (',' FROM l_batch_nos);
            l_return      :=
                fnd_concurrent.set_completion_status (
                    'WARNING',
                    'Some of the Batch Numbers  has errors.');

            IF p_conc_pgm_name = 'XXD_ITEM_VAL_WRK'
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'The following Batch Number(s) '
                    || l_batch_nos
                    || ' has errors.');
            END IF;
        END IF;

        IF l_error_cnt > 0
        THEN
            l_batch_nos   := TRIM (',' FROM l_batch_nos);
            l_return      :=
                fnd_concurrent.set_completion_status (
                    'ERROR',
                    'Some of the Batch Numbers  has errors.');

            IF p_conc_pgm_name = 'XXD_ITEM_VAL_WRK'
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'The following Batch Numbers '
                    || l_batch_nos
                    || ' has errors.');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_batch_org%ISOPEN
            THEN
                CLOSE get_batch_org;
            END IF;

            x_retcode   := 2;
            x_errbuf    :=
                   'OTHERS Exception in the Procedure submit_child_requests.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure submit_child_requests:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure submit_child_requests.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     import_items                                                           |
    |                                                                            |
    | DESCRIPTION                                                                |
    | Procedure import_items submits the standard program 'Import Items'         |
    +===========================================================================*/
    PROCEDURE import_items (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_organization_id IN NUMBER
                            , p_batch_number IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_request_id   NUMBER;
    BEGIN
        --Calling Import Items Program
        v_request_id   :=
            fnd_request.submit_request (application => 'INV', program => 'INCOIN', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => p_organization_id, -- Organization id
                                                                                                                                                                                     argument2 => 1, -- All organizations
                                                                                                                                                                                                     argument3 => 1, -- Validate Items
                                                                                                                                                                                                                     argument4 => 1, -- Process Items
                                                                                                                                                                                                                                     argument5 => 1, -- Delete Processed Rows
                                                                                                                                                                                                                                                     argument6 => p_batch_number, -- Process Set (Null for All)
                                                                                                                                                                                                                                                                                  argument7 => 1
                                        ,            -- Create or Update Items
                                          argument8 => 1  -- Gather Statistics
                                                        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    :=
                   'OTHERS Exception in the Procedure import_items.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure import_items:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure import_items.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END;

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
    PROCEDURE get_org_id (p_org_name IN VARCHAR2           -- New inv_org_name
                                                , x_org_id OUT NOCOPY NUMBER) -- old inv_org_id (Based on the old name conter to new name)
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
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING',
            -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1,
            -- corresponding new 12.2.3 value
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
            print_log ('Exception to GET_ORG_ID Procedure' || SQLERRM);
    END get_org_id;

    /*+=========================================================================================+
    | Procedure name                                                                         |
    |     extract_val_load_main                                                                 |
    |                                                                                        |
    | DESCRIPTION                                                                            |
    | Procedure extract_val_load_main is the main program to be called for the Item conversion  |
    | process.Based on the value passed to Parameter p_process_level, Either extract from       |
    | R12 instance using the view XXD_ITEM_CONV_V and inserts into staging table                |
    | XXD_ITEM_CONV_STG_T validation of the records                          |
    | in the staging table or loading of records into interface table, takes place in this      |
    | procedure.                                                    |
    +==========================================================================================*/
    PROCEDURE extract_val_load_main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_organization_code IN VARCHAR2, p_process_level IN VARCHAR2, p_batch_size IN NUMBER, p_debug_flag IN VARCHAR2 DEFAULT 'N'
                                     , p_brand IN VARCHAR2)
    IS
        --Variable declarations
        l_eligible_records           NUMBER;
        l_organization_code          VARCHAR2 (240);
        l_master_organization_code   VARCHAR2 (240);
        l_err_msg                    VARCHAR2 (4000);
        l_err_code                   NUMBER;
        l_low_batch_limit            NUMBER;
        l_high_batch_limit           NUMBER;
        l_interface_rec_cnt          NUMBER;
        l_organization_id            NUMBER;
        l_request_id                 NUMBER;
        l_succ_interfc_rec_cnt       NUMBER := 0;
        l_warning_cnt                NUMBER := 0;
        l_error_cnt                  NUMBER := 0;
        l_return                     BOOLEAN;
        lc_phase                     VARCHAR2 (200);
        lc_status                    VARCHAR2 (200);
        lc_dev_phase                 VARCHAR2 (200);
        lc_dev_status                VARCHAR2 (200);
        lc_message                   VARCHAR2 (200);
        ln_ret_code                  NUMBER;
        lc_err_buff                  VARCHAR2 (1000);
        lb_wait                      BOOLEAN;
        --  ln_count               NUMBER;
        ln_cntr                      NUMBER := 0;
        l_instance                   VARCHAR2 (1000);
        l_batch_nos                  VARCHAR2 (1000);
        l_sub_requests               fnd_concurrent.requests_tab_type;
        l_errored_rec_cnt            NUMBER;
        l_validated_rec_cnt          NUMBER;
        v_request_id                 NUMBER;
        --  g_debug                      VARCHAR2 (10);
        ln_count                     NUMBER := 0;
        ln_total_count               NUMBER := 0;
        ln_conv_stg_seq              NUMBER := 0;
        ld_date                      DATE;
        l_insert_org_id              NUMBER := 0;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id              hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                     request_table;
        ln_valid_rec_cnt             NUMBER;
        p_batch_cnt                  NUMBER;
        ln_organization_id           NUMBER;

        --Cursor to get organization_code from mtl_parameters
        CURSOR c_org_code IS
              SELECT DISTINCT mp.organization_code
                FROM mtl_parameters mp, org_organization_definitions ood
               WHERE     mp.organization_id = ood.organization_id
                     AND TRUNC (NVL (ood.disable_date, SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND mp.organization_code =
                         NVL (p_organization_code, mp.organization_code)
            ORDER BY mp.organization_code ASC;

        --Cursor for distinct batch number
        CURSOR c1 (p_batch_low_limit NUMBER, p_batch_high_limit NUMBER)
        IS
              SELECT batch_number, organization_code, organization_id
                FROM xxd_item_conv_stg_t
               WHERE     batch_number BETWEEN p_batch_low_limit
                                          AND p_batch_high_limit
                     AND organization_code =
                         NVL (p_organization_code, organization_code)
            GROUP BY batch_number, organization_code, organization_id
            ORDER BY batch_number;

        --      -- Cursor to get the distinct batches for load
        --      CURSOR c_load_batch
        --      IS
        --         select distinct batch_number
        --         from xxd_item_conv_stg_t
        --         where organization_code = p_organization_code;
        --
        --      TYPE c_load_batch_type IS TABLE OF c_load_batch%ROWTYPE
        --                             INDEX BY BINARY_INTEGER;
        --
        --      c_load_batch_tab  c_load_batch_type;

        --Cursor for fetch the records from view  XXD_ITEM_CONV_V
        CURSOR c_main (p_org_id NUMBER)
        IS
            SELECT xxd_item_conv_stg_seq.NEXTVAL record_id, NULL batch_number, 'N' record_status,
                   /* inventory_item_id,                                   --pawan30
                    organization_code,
                    organization_id,
                    summary_flag,
                    enabled_flag,
                    start_date_active,
                    end_date_active,
                    description,
                    buyer,
                    NULL buyer_id,
                    accounting_rule_id,
                    invoicing_rule_id,
                    segment1,
                    segment2,
                    segment3,
                    segment4,
                    segment5,
                    segment6,
                    segment7,
                    segment8,
                    segment9,
                    segment10,
                    segment11,
                    segment12,
                    segment13,
                    segment14,
                    segment15,
                    segment16,
                    segment17,
                    segment18,
                    segment19,
                    segment20,
                    attribute_category,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    attribute6,
                    attribute7,
                    attribute8,
                    attribute9,
                    attribute10,
                    attribute11,
                    attribute12,
                    attribute13,
                    attribute14,
                    attribute15,
                    purchasing_item_flag,
                    shippable_item_flag,
                    customer_order_flag,
                    internal_order_flag,
                    service_item_flag,
                    inventory_item_flag,
                    eng_item_flag,
                    inventory_asset_flag,
                    purchasing_enabled_flag,
                    customer_order_enabled_flag,
                    internal_order_enabled_flag,
                    so_transactions_flag,
                    mtl_transactions_enabled_flag,
                    stock_enabled_flag,
                    bom_enabled_flag,
                    build_in_wip_flag,
                    revision_qty_control_code,
                    item_catalog_group_id,
                    catalog_status_flag,
                    check_shortages_flag,
                    returnable_flag,
                    default_shipping_org,
                    collateral_flag,
                    taxable_flag,
                    qty_rcv_exception_code,
                    allow_item_desc_update_flag,
                    inspection_required_flag,
                    receipt_required_flag,
                    market_price,
                    hazard_class_id,
                    rfq_required_flag,
                    qty_rcv_tolerance,
                    list_price_per_unit,
                    un_number_id,
                    price_tolerance_percent,
                    asset_category_id,
                    rounding_factor,
                    unit_of_issue,
                    enforce_ship_to_location_code,
                    allow_substitute_receipts_flag,
                    allow_unordered_receipts_flag,
                    allow_express_delivery_flag,
                    days_early_receipt_allowed,
                    days_late_receipt_allowed,
                    receipt_days_exception_code,
                    receiving_routing_id,
                    invoice_close_tolerance,
                    receive_close_tolerance,
                    auto_lot_alpha_prefix,
                    start_auto_lot_number,
                    lot_control_code,
                    shelf_life_code,
                    shelf_life_days,
                    serial_number_control_code,
                    start_auto_serial_number,
                    auto_serial_alpha_prefix,
                    source_type,
                    source_organization_code,
                    NULL source_organization_id,
                    source_subinventory,
                    expense_account_no orig_expense_account_no,
                    expense_account orig_expense_account,
                    encumbrance_account_no orig_encumbrance_account_no,
                    encumbrance_account orig_encumbrance_account,
                    NULL expense_account_no,
                    NULL expense_account,
                    NULL encumbrance_account_no,
                    NULL encumbrance_account,
                    restrict_subinventories_code,
                    unit_weight,
                    weight_uom_code,
                    volume_uom_code,
                    unit_volume,
                    restrict_locators_code,
                    location_control_code,
                    shrinkage_rate,
                    acceptable_early_days,
                    planning_time_fence_code,
                    demand_time_fence_code,
                    lead_time_lot_size,
                    std_lot_size,
                    cum_manufacturing_lead_time,
                    overrun_percentage,
                    mrp_calculate_atp_flag,
                    acceptable_rate_increase,
                    acceptable_rate_decrease,
                    cumulative_total_lead_time,
                    planning_time_fence_days,
                    demand_time_fence_days,
                    end_assembly_pegging_flag,
                    repetitive_planning_flag,
                    planning_exception_set,
                    bom_item_type,
                    pick_components_flag,
                    replenish_to_order_flag,
                    base_item_id,
                    atp_components_flag,
                    atp_flag,
                    fixed_lead_time,
                    variable_lead_time,
                    wip_supply_locator_id,
                    wip_supply_type,
                    wip_supply_subinventory,
                    primary_uom_code,
                    primary_unit_of_measure,
                    allowed_units_lookup_code,
                    cost_of_sales_account_no orig_cost_of_sales_account_no,
                    cost_of_sales_account orig_cost_of_sales_account,
                    sales_account_no orig_sales_account_no,
                    sales_account orig_sales_account,
                    NULL cost_of_sales_account_no,
                    NULL cost_of_sales_account,
                    NULL sales_account_no,
                    NULL sales_account,
                    default_include_in_rollup_flag,
                    inventory_item_status_code,
                    inventory_planning_code,
                    planner_code,
                    planning_make_buy_code,
                    fixed_lot_multiplier,
                    rounding_control_type,
                    carrying_cost,
                    postprocessing_lead_time,
                    preprocessing_lead_time,
                    full_lead_time,
                    order_cost,
                    mrp_safety_stock_percent,
                    mrp_safety_stock_code,
                    min_minmax_quantity,
                    max_minmax_quantity,
                    minimum_order_quantity,
                    fixed_order_quantity,
                    --fixed_days_supply,
                    maximum_order_quantity,
                    atp_rule_id,
                    picking_rule_id,
                    reservable_type,
                    positive_measurement_error,
                    negative_measurement_error,
                    engineering_ecn_code,
                    engineering_item_id,
                    engineering_date,
                    service_starting_delay,
                    vendor_warranty_flag,
                    serviceable_component_flag,
                    serviceable_product_flag,
                    base_warranty_service_id,
                    payment_terms_id,
                    preventive_maintenance_flag,
                    primary_specialist_id,
                    secondary_specialist_id,
                    serviceable_item_class_id,
                    time_billable_flag,
                    material_billable_flag,
                    expense_billable_flag,
                    prorate_service_flag,
                    coverage_schedule_id,
                    service_duration_period_code,
                    service_duration,
                    warranty_vendor_id,
                    max_warranty_amount,
                    response_time_period_code,
                    response_time_value,
                    new_revision_code,
                    invoiceable_item_flag,
                    tax_code,
                    invoice_enabled_flag,
                    must_use_approved_vendor_flag,
                    XIB.request_id,
                    program_application_id,
                    program_id,
                    program_update_date,
                    outside_operation_flag,
                    outside_operation_uom_type,
                    safety_stock_bucket_days,
                    auto_reduce_mps,
                    costing_enabled_flag,
                    cycle_count_enabled_flag,
                    demand_source_line,
                    copy_item_id,
                    set_id,
                    NULL revision,
                    auto_created_config_flag,
                    item_type,
                    model_config_clause_name,
                    ship_model_complete_flag,
                    mrp_planning_code,
                    return_inspection_requirement,
                    demand_source_type,
                    demand_source_header_id,
                    transaction_id,
                    process_flag,
                    item_number,                                          -- pawan
                    copy_item_number,
                    template_id,
                    template_name,
                    copy_organization_id,
                    copy_organization_code,
                    ato_forecast_control,
                    transaction_type,
                    material_cost,
                    material_sub_elem,
                    material_oh_rate,
                    material_oh_sub_elem,
                    material_sub_elem_id,
                    material_oh_sub_elem_id,
                    release_time_fence_code,
                    release_time_fence_days,
                    container_item_flag,
                    vehicle_item_flag,
                    maximum_load_weight,
                    minimum_fill_percent,
                    container_type_code,
                    internal_volume,
                    set_process_id,
                    wh_update_date,
                    product_family_item_id,
                    purchasing_tax_code,
                    overcompletion_tolerance_type,
                    overcompletion_tolerance_value,
                    effectivity_control,
                    global_attribute_category,
                    global_attribute1,
                    global_attribute2,
                    global_attribute3,
                    global_attribute4,
                    global_attribute5,
                    global_attribute6,
                    global_attribute7,
                    global_attribute8,
                    global_attribute9,
                    global_attribute10,
                    over_shipment_tolerance,
                    under_shipment_tolerance,
                    over_return_tolerance,
                    under_return_tolerance,
                    equipment_type,
                    recovered_part_disp_code,
                    defect_tracking_on_flag,
                    usage_item_flag,
                    event_flag,
                    electronic_flag,
                    downloadable_flag,
                    vol_discount_exempt_flag,
                    coupon_exempt_flag,
                    comms_nl_trackable_flag,
                    asset_creation_code,
                    comms_activation_reqd_flag,
                    orderable_on_web_flag,
                    back_orderable_flag,
                    web_status,
                    indivisible_flag,
                    long_description,
                    dimension_uom_code,
                    unit_length,
                    unit_width,
                    unit_height,
                    bulk_picked_flag,
                    lot_status_enabled,
                    default_lot_status_id,
                    serial_status_enabled,
                    default_serial_status_id,
                    lot_split_enabled,
                    lot_merge_enabled,
                    inventory_carry_penalty,
                    operation_slack_penalty,
                    financing_allowed_flag,
                    eam_item_type,
                    eam_activity_type_code,
                    eam_activity_cause_code,
                    eam_act_notification_flag,
                    eam_act_shutdown_status,
                    dual_uom_control,
                    secondary_uom_code,
                    dual_uom_deviation_high,
                    dual_uom_deviation_low,
                    contract_item_type_code,
                    subscription_depend_flag,
                    serv_req_enabled_code,
                    serv_billing_enabled_flag,
                    serv_importance_level,
                    planned_inv_point_flag,
                    lot_translate_enabled,
                    default_so_source_type,
                    create_supply_flag,
                    substitution_window_code,
                    substitution_window_days,
                    ib_item_instance_class,
                    config_model_type,
                    lot_substitution_enabled,
                    minimum_license_quantity,
                    eam_activity_source_code,
                    lifecycle_id,
                    current_phase_id,
                    tracking_quantity_ind,
                    ont_pricing_qty_source,
                    secondary_default_ind,
                    vmi_minimum_units,
                    vmi_minimum_days,
                    vmi_maximum_units,
                    vmi_maximum_days,
                    vmi_fixed_order_quantity,
                    so_authorization_flag,
                    consigned_flag,
                    asn_autoexpire_flag,
                    vmi_forecast_type,
                    forecast_horizon,
                    exclude_from_budget_flag,
                    days_tgt_inv_supply,
                    days_tgt_inv_window,
                    days_max_inv_supply,
                    days_max_inv_window,
                    drp_planned_flag,
                    critical_component_flag,
                    continous_transfer,
                    convergence,
                    divergence,
                    config_orgs,
                    config_match,
                    attribute16,
                    attribute17,
                    attribute18,
                    attribute19,
                    attribute20,
                    attribute21,
                    attribute22,
                    attribute23,
                    attribute24,
                    attribute25,
                    attribute26,
                    attribute27,
                    attribute28,
                    attribute29,
                    attribute30,
                    cas_number,
                    child_lot_flag,
                    child_lot_prefix,
                    child_lot_starting_number,
                    child_lot_validation_flag,
                    copy_lot_attribute_flag,
                    default_grade,
                    expiration_action_code,
                    expiration_action_interval,
                    grade_control_flag,
                    hazardous_material_flag,
                    hold_days,
                    lot_divisible_flag,
                    maturity_days,
                    parent_child_generation_flag,
                    process_costing_enabled_flag,
                    process_execution_enabled_flag,
                    process_quality_enabled_flag,
                    process_supply_locator_id,
                    process_supply_subinventory,
                    process_yield_locator_id,
                    process_yield_subinventory,
                    recipe_enabled_flag,
                    retest_interval,
                    charge_periodicity_code,
                    repair_leadtime,
                    repair_yield,
                    preposition_point,
                    repair_program,
                    subcontracting_component,
                    outsourced_assembly,
                    source_system_id,
                    source_system_reference,
                    source_system_reference_desc,
                    global_trade_item_number,
                    confirm_status,
                    change_id,
                    change_line_id,
                    item_catalog_group_name,
                    max_item_id,
                    SAMPLE_ITEM*/
                   ITEM_NUMBER, INVENTORY_ITEM_ID, max_item_id,
                   DESCRIPTION, LONG_DESCRIPTION, INVENTORY_ITEM_STATUS_CODE,
                   PRIMARY_UOM_CODE, PRIMARY_UNIT_OF_MEASURE, RETURN_INSPECTION_REQUIREMENT,
                   UNIT_LENGTH, UNIT_WIDTH, UNIT_HEIGHT,
                   UNIT_VOLUME, WEIGHT_UOM_CODE, VOLUME_UOM_CODE,
                   DIMENSION_UOM_CODE, UNIT_WEIGHT, LIST_PRICE_PER_UNIT,
                   POSTPROCESSING_LEAD_TIME, FULL_LEAD_TIME, ATTRIBUTE10,
                   attribute11, attribute13, ATTRIBUTE15,
                   INTRO_SEASON, SAMPLE_ITEM, ATTRIBUTE2,
                   ATTRIBUTE1, ATTRIBUTE3, ATTRIBUTE4,
                   ATTRIBUTE5, ATTRIBUTE6, ATTRIBUTE7,
                   ATTRIBUTE8, segment1, segment2,
                   SEGMENT3, ORGANIZATION_ID
              /*PL_SEG1,
              PL_SEG2,
              PL_SEG3,
              QR_SEG1,
              TX_SEG1 ,
              TC_SEG1,
              TC_SEG2,
              TC_SEG3,
              TC_SEG4  */
              FROM XXD_CONV.XXD_ITEM_1206_EXTRACT XIB
             --XXD_CONV.XXD_PLM_ATTR_STG_T XPAS
             WHERE     1 = 1
                   AND XIB.organization_id =
                       NVL (p_org_id, XIB.organization_id)--AND inventory_item_id = 100119
                                                          --IN (select inventory_item_id from  XXD_ITEM_ID2)
                                                          --   (select inventory_item_id from mtl_item_categories where category_set_id = 1 and organization_id = 106 and category_id not in ( 1133,88507))
                                                          --AND substr(ITEM_NUMBER,1,(instr(ITEM_NUMBER,'-',1,2)-1)) in (select STYLE_CODE||'-'||COLOR_CODE from  Xxd_Conv.Xxd_Plm_Attr_Stg_T)
                                                          ;



        TYPE c_main_type IS TABLE OF c_main%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_main_tab                  c_main_type;



        CURSOR get_org_id_c IS
            SELECT organization_id, organization_code
              FROM mtl_parameters
             WHERE (attribute13 = 2 OR organization_code = 'MST');

        /*       'MST',
                        'US1',
                        'US2',
                        'US3',
                        'EUC',
                        'CH3',
                        'CH4',
                        'HK1',
                        'JP5',
                        'JPC',
                        'MC1',
                        'MC2',
                        'EUZ',
                        'EUB',
                        'CNC',
                        'HKC',
                        'FLG',
                        'APB',
                        --'XXC',
                        'USB',
                        'USC',
                        'USX',
                        'USZ',
                        'EU3',
                        'EU4'); */

        ln_org_id                    NUMBER;
        lc_organization_code         VARCHAR2 (100);


        CURSOR get_inv_org_id_c IS
            SELECT xie.inventory_item_id, ood.organization_id, xie.LIST_PRICE_PER_UNIT,
                   xie.FULL_LEAD_TIME
              FROM XXD_CONV.XXD_ITEM_1206_EXTRACT xie, fnd_lookup_values flv, org_organization_definitions ood
             WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                   AND language = 'US'
                   AND XIE.organization_id = flv.LOOKUP_CODE
                   AND flv.attribute1 = ood.organization_code--AND substr(XIE.ITEM_NUMBER,1,(instr(ITEM_NUMBER,'-',1,2)-1)) in (select STYLE_CODE||'-'||COLOR_CODE from  Xxd_Conv.Xxd_Plm_Attr_Stg_T)
                                                             -- IN (select inventory_item_id from  XXD_ITEM_ID2)
                                                             --(select inventory_item_id from mtl_item_categories where category_set_id = 1 and organization_id = 106 and category_id not in ( 1133,88507))
                                                             ;

        lcu_get_inv_org_id_c         get_inv_org_id_c%ROWTYPE;

        CURSOR get_org_code_c IS
            SELECT mp.organization_code
              FROM mtl_system_items_interface msi, mtl_parameters mp
             WHERE mp.organization_id = msi.organization_id AND ROWNUM = 1;

        lc_org_code                  VARCHAR2 (10);

        lc_query                     VARCHAR2 (2000);
    BEGIN
        g_debug   := p_debug_flag;
        fnd_file.put_line (fnd_file.LOG, 'Debug flag' || p_debug_flag);
        --fnd_file.put_line (fnd_file.LOG, 'org_id ' || p_organization_code);
        print_log (
               'Procedure val_load_main (p_organization_code,p_process_level,p_batch_size)'
            || p_organization_code
            || ', '
            || p_process_level
            || ', '
            || p_batch_size);

        --Extract Process starts here
        IF p_process_level = 'EXTRACT'
        THEN
            print_log ('Procedure extract_main');

            --Commented for bt changes

            --EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_ITEM_CONV_STG_T';

            BEGIN
                l_organization_id   := NULL;
                get_org_id_1206 (p_organization_code, l_organization_id);

                /*  IF l_organization_id IS NULL THEN
                  fnd_file.put_line(fnd_file.log,'Check the lookup XXD_1206_INV_ORG_MAPPING for mapping for the current organization ');
                  RETURN;
                  END IF; */

                SELECT organization_id
                  INTO l_insert_org_id
                  FROM mtl_parameters
                 WHERE organization_code = p_organization_code;

                print_log (
                       'p_organization_code = '
                    || p_organization_code
                    || 'l_insert_org_id = '
                    || l_insert_org_id);
                print_log (
                       'GET_ORG_ID_1206(p_organization_code, l_organization_id); '
                    || p_organization_code
                    || ', 12 0 6 Org Id '
                    || l_organization_id);
                --            SELECT organization_id
                --              INTO l_organization_id
                --              --FROM mtl_parameters@apps_r12_da
                --              FROM mtl_parameters@bt_read_1206
                --             WHERE organization_code = p_organization_code;
                print_log ('Start Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
                print_log (
                       'Inserting to Staging Table XXD_ITEM_CONV_STG_T for Org Code:'
                    || l_organization_id);

                SELECT SYSDATE INTO ld_date FROM SYS.DUAL;

                OPEN get_org_id_c;

                LOOP
                    ln_org_id              := NULL;
                    lc_organization_code   := NULL;

                    FETCH get_org_id_c INTO ln_org_id, lc_organization_code;

                    EXIT WHEN get_org_id_c%NOTFOUND;

                    OPEN c_main (p_org_id => l_organization_id);

                    print_log ('l_organization_id : ' || l_organization_id);
                    print_log ('Rows in c_main:' || c_main%ROWCOUNT);

                    LOOP
                        FETCH c_main
                            BULK COLLECT INTO lt_main_tab
                            LIMIT 20000;

                        FORALL i IN 1 .. lt_main_tab.COUNT
                            --Inserting to Staging Table XXD_ITEM_CONV_STG_T for Org Code
                            INSERT INTO XXD_ITEM_CONV_STG_T (record_id, max_item_id, batch_number, record_status, inventory_item_id, organization_code, organization_id, last_update_date, last_updated_by, creation_date, created_by, last_update_login, ITEM_NUMBER, DESCRIPTION, LONG_DESCRIPTION, INVENTORY_ITEM_STATUS_CODE, PRIMARY_UOM_CODE, PRIMARY_UNIT_OF_MEASURE, RETURN_INSPECTION_REQUIREMENT, UNIT_LENGTH, UNIT_WIDTH, UNIT_HEIGHT, UNIT_VOLUME, WEIGHT_UOM_CODE, VOLUME_UOM_CODE, DIMENSION_UOM_CODE, UNIT_WEIGHT, --LIST_PRICE_PER_UNIT,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  POSTPROCESSING_LEAD_TIME, -- FULL_LEAD_TIME,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ATTRIBUTE10, attribute11, ATTRIBUTE15, INTR_SEASON, SAMPLE_ITEM, ATTRIBUTE1, ATTRIBUTE13, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, ATTRIBUTE6, ATTRIBUTE7, ATTRIBUTE8, ATTRIBUTE27, CLOSEOUT_FLAG, segment1
                                                             , segment2)
                                 VALUES (lt_main_tab (i).record_id, lt_main_tab (i).max_item_id, NULL, 'N', lt_main_tab (i).inventory_item_id, lc_organization_code, ln_org_id, ld_date, fnd_global.user_id, ld_date, fnd_global.user_id, fnd_global.login_id, lt_main_tab (i).ITEM_NUMBER, lt_main_tab (i).DESCRIPTION, lt_main_tab (i).LONG_DESCRIPTION, --Star Modified 13-Apr-2015
                                                                                                                                                                                                                                                                                                                                                           --lt_main_tab (i).INVENTORY_ITEM_STATUS_CODE,
                                                                                                                                                                                                                                                                                                                                                           'Active', --lt_main_tab (i).INVENTORY_ITEM_STATUS_CODE,
                                                                                                                                                                                                                                                                                                                                                                     --End Modified 13-Apr-2015
                                                                                                                                                                                                                                                                                                                                                                     lt_main_tab (i).PRIMARY_UOM_CODE, lt_main_tab (i).PRIMARY_UNIT_OF_MEASURE, lt_main_tab (i).RETURN_INSPECTION_REQUIREMENT, lt_main_tab (i).UNIT_LENGTH, lt_main_tab (i).UNIT_WIDTH, lt_main_tab (i).UNIT_HEIGHT, lt_main_tab (i).UNIT_VOLUME, lt_main_tab (i).WEIGHT_UOM_CODE, lt_main_tab (i).VOLUME_UOM_CODE, lt_main_tab (i).DIMENSION_UOM_CODE, lt_main_tab (i).UNIT_WEIGHT, --lt_main_tab (i).LIST_PRICE_PER_UNIT,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lt_main_tab (i).POSTPROCESSING_LEAD_TIME, -- lt_main_tab (i).FULL_LEAD_TIME,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               lt_main_tab (i).ATTRIBUTE10, lt_main_tab (i).attribute11, lt_main_tab (i).ATTRIBUTE15, lt_main_tab (i).INTRO_SEASON, lt_main_tab (i).SAMPLE_ITEM, lt_main_tab (i).ATTRIBUTE1, lt_main_tab (i).ATTRIBUTE13, lt_main_tab (i).ATTRIBUTE2, lt_main_tab (i).ATTRIBUTE3, lt_main_tab (i).ATTRIBUTE4, lt_main_tab (i).ATTRIBUTE5, lt_main_tab (i).ATTRIBUTE6, lt_main_tab (i).ATTRIBUTE7, lt_main_tab (i).ATTRIBUTE8, lt_main_tab (i).SEGMENT3, DECODE (lt_main_tab (i).INVENTORY_ITEM_STATUS_CODE, 'CloseOut', 'Y'), lt_main_tab (i).SEGMENT1
                                         , lt_main_tab (i).SEGMENT2);

                        ln_total_count   := ln_total_count + ln_count;
                        ln_count         := ln_count + 1;

                        IF ln_total_count = 20000
                        THEN
                            ln_total_count   := 0;
                            ln_count         := 0;
                            COMMIT;
                        END IF;

                        --END LOOP;
                        EXIT WHEN lt_main_tab.COUNT < 20000;
                    END LOOP;

                    CLOSE c_main;
                END LOOP;

                CLOSE get_org_id_c;

                print_log ('End Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Org Code:'
                        || p_organization_code
                        || ' does not exist in 11i'
                        || SQLERRM);
            END;

            --Validation Process starts here.

            --List price ,Processing time
            OPEN get_inv_org_id_c;


            LOOP
                lcu_get_inv_org_id_c   := NULL;

                FETCH get_inv_org_id_c INTO lcu_get_inv_org_id_c;

                EXIT WHEN get_inv_org_id_c%NOTFOUND;

                UPDATE XXD_ITEM_CONV_STG_T
                   SET LIST_PRICE_PER_UNIT = lcu_get_inv_org_id_c.LIST_PRICE_PER_UNIT, FULL_LEAD_TIME = lcu_get_inv_org_id_c.FULL_LEAD_TIME
                 WHERE     organization_id =
                           lcu_get_inv_org_id_c.organization_id
                       AND inventory_item_id =
                           lcu_get_inv_org_id_c.inventory_item_id;

                ln_count               := ln_count + 1;

                IF ln_count = 1000
                THEN
                    ln_count   := 0;
                    COMMIT;
                END IF;
            END LOOP;

            CLOSE get_inv_org_id_c;
        --List price ,Processing time

        ELSIF p_process_level = 'VALIDATE'
        THEN
            IF p_organization_code IS NOT NULL
            THEN
                print_log (
                       'Call Procedure get_master_org_prc (organization code) : '
                    || p_organization_code);
                get_master_org_prc (
                    p_organization_code     => p_organization_code,
                    x_organization_code     => l_organization_code,
                    x_m_organization_code   => l_master_organization_code);
                print_log (
                    'get_master_org_prc procedure completed sucessfully');

                --If its a Master Organization code
                IF p_organization_code = l_master_organization_code
                THEN
                    --Get the record count for Master Org
                    print_log (
                        ' calling calc_eligible_records if its master org');
                    l_eligible_records   :=
                        calc_eligible_records (
                            p_organization_code => p_organization_code);
                    print_log (
                        'p_organization_code = ' || p_organization_code);
                --If its a Child Organization code
                ELSIF p_organization_code = l_organization_code
                THEN
                    --Get the record count for Chils Org
                    print_log (
                        ' calling calc_eligible_records if its child org');
                    l_eligible_records   :=
                        calc_eligible_records (
                            p_organization_code => p_organization_code);
                END IF;
            --If no organization is passed as parameter
            ELSE
                --Get the record count, if no org is passed as parameter
                l_eligible_records   :=
                    calc_eligible_records (
                        p_organization_code => p_organization_code);
            END IF;

            --If there are eligible records to be processed.
            IF l_eligible_records > 0
            THEN
                print_log (
                    'eligible records to be processed.' || l_eligible_records);
                print_log (
                       'Call Procedure create_batch_prc. Batch Size:'
                    || p_batch_size);
                print_log (
                       'Call Procedure create_batch_prc. p_organization_code:'
                    || p_organization_code);

                --            create_batch_prc (p_organization_code   => p_organization_code,
                --                              p_batch_size          => p_batch_size,
                --                              x_err_msg             => l_err_msg,
                --                              x_err_code            => l_err_code);
                --
                --            min_max_batch_prc (x_low_batch_limit    => l_low_batch_limit,
                --                               x_high_batch_limit   => l_high_batch_limit);

                --          GET_ORG_ID_1206 (p_org_name  =>        p_organization_code     -- New inv_org_name
                --                            ,x_org_id  =>        ln_organization_id)  ;
                --          print_log ( 'Call Procedure create_batch_prc. ln_organization_id:' || ln_organization_id);
                SELECT organization_id
                  INTO ln_organization_id
                  FROM mtl_parameters
                 WHERE organization_code = p_organization_code;

                print_log (
                       'Call Procedure create_batch_prc. ln_organization_id:'
                    || ln_organization_id);

                UPDATE xxd_item_conv_stg_t
                   SET batch_number   = NULL
                 WHERE record_status = 'E';

                SELECT COUNT (*)
                  INTO ln_valid_rec_cnt
                  FROM xxd_item_conv_stg_t
                 WHERE     batch_number IS NULL
                       AND organization_id = ln_organization_id
                       AND record_status IN ('N', 'E');

                p_batch_cnt   := p_batch_size;

                FOR i IN 1 .. p_batch_cnt
                LOOP
                    BEGIN
                        SELECT xxd_item_conv_bth_seq.NEXTVAL
                          INTO ln_hdr_batch_id (i)
                          FROM DUAL;

                        print_log (
                            'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_hdr_batch_id (i + 1)   :=
                                ln_hdr_batch_id (i) + 1;
                    END;

                    print_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                    print_log (
                           'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                        || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                    UPDATE xxd_item_conv_stg_t
                       SET batch_number   = ln_hdr_batch_id (i)
                     --, REQUEST_ID = ln_parent_request_id
                     WHERE     batch_number IS NULL
                           AND ROWNUM <=
                               CEIL (ln_valid_rec_cnt / p_batch_cnt)
                           AND organization_id = ln_organization_id
                           AND record_status IN ('N', 'E');
                END LOOP;

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM xxd_item_conv_stg_t
                     WHERE batch_number = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            l_request_id   :=
                                fnd_request.submit_request (
                                    application   => 'XXDCONV',
                                    --Submitting Child Requests
                                    program       => 'XXD_ITEM_VAL_WRK',
                                    argument1     => p_organization_code,
                                    argument2     => ln_hdr_batch_id (i),
                                    argument3     => ln_hdr_batch_id (i),
                                    argument4     => p_brand);

                            IF l_request_id > 0
                            THEN
                                l_req_id (i)   := l_request_id;
                                COMMIT;
                            ELSE
                                ROLLBACK;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                print_log (
                                       'Calling WAIT FOR REQUEST XXD_ITEM_LOAD_WRK error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                print_log (
                                       'Calling WAIT FOR REQUEST XXD_ITEM_LOAD_WRK error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;

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
                                        INTERVAL     => 1,
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
            --            print_log (
            --                  'Call Procedure min_max_batch_prc.'
            --               || l_low_batch_limit
            --               || '-'
            --               || l_high_batch_limit);
            --
            --            print_log ('Call Procedure submit_child_requests');
            --
            --            submit_child_requests (
            --               x_errbuf              => l_err_msg,
            --               x_retcode             => l_err_code,
            --               p_organization_code   => p_organization_code,
            --               p_appln_shrt_name     => 'XXDCONV',
            --               p_conc_pgm_name       => 'XXD_ITEM_VAL_WRK',
            --               p_batch_low_limit     => l_low_batch_limit,
            --               p_batch_high_limit    => l_high_batch_limit);
            ELSE
                l_return   :=
                    fnd_concurrent.set_completion_status (
                        'WARNING',
                        'No eligible records are available in the staging table XX_ITEM_CONV_STG_T to be processed.');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No eligible records are available in the staging table XX_ITEM_CONV_STG_T to be processed.');
            END IF;
        ELSIF p_process_level = 'LOAD'
        THEN
            --Modified to create back up tables
            /*  OPEN get_org_code_c;

              lc_org_code := NULL;

              FETCH get_org_code_c INTO lc_org_code;

              CLOSE get_org_code_c;

                     IF lc_org_code IS NOT NULL
                       THEN
                          BEGIN
                             lc_query := NULL;


                             BEGIN
                                lc_query :=
                                   'DROP TABLE MTL_SYSTEM_' || lc_org_code || '_INT';

                                EXECUTE IMMEDIATE lc_query;
                             EXCEPTION
                                WHEN OTHERS
                                THEN
                                   NULL;
                             END;

                             lc_query := NULL;

                             lc_query :=
                                   'CREATE TABLE MTL_SYSTEM_'
                                || lc_org_code
                                || '_INT  AS SELECT * FROM MTL_SYSTEM_ITEMS_INTERFACE';

                             fnd_file.put_line (fnd_file.LOG, 'lc_query ' || lc_query);

                             EXECUTE IMMEDIATE lc_query;

                             DELETE mtl_system_items_interface;

                             BEGIN
                                lc_query := 'DROP TABLE MTL_ERR_' || lc_org_code || '_INT';

                                EXECUTE IMMEDIATE lc_query;
                             EXCEPTION
                                WHEN OTHERS
                                THEN
                                   NULL;
                             END;

                             lc_query := NULL;
                             lc_query :=
                                   'CREATE TABLE MTL_ERR_'
                                || lc_org_code
                                || '_INT  AS SELECT * FROM MTL_INTERFACE_ERRORS';

                             fnd_file.put_line (fnd_file.LOG, 'lc_query ' || lc_query);

                             EXECUTE IMMEDIATE lc_query;

                             DELETE MTL_INTERFACE_ERRORS;
                          EXCEPTION
                             WHEN OTHERS
                             THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Error while executing taking back up');
                          END;
                       END IF;*/

            --Modified to create back up tables

            BEGIN                                  --Load Process starts here.
                print_log ('Loading Process Initiated');
                --         print_log ('Call Procedure min_max_batch_prc');
                --         min_max_batch_prc (x_low_batch_limit    => l_low_batch_limit,
                --                            x_high_batch_limit   => l_high_batch_limit);
                --         print_log (
                --               'After Call Procedure min_max_batch_prc.'
                --            || l_low_batch_limit
                --            || '-'
                --            || l_high_batch_limit);
                --
                --
                --         print_log ('Call Procedure submit_child_requests');
                --
                --         submit_child_requests (x_errbuf              => l_err_msg,
                --                                x_retcode             => l_err_code,
                --                                p_organization_code   => p_organization_code,
                --                                p_appln_shrt_name     => 'XXDCONV',
                --                                p_conc_pgm_name       => 'XXD_ITEM_LOAD_WRK',
                --                                p_batch_low_limit     => l_low_batch_limit,
                --                                p_batch_high_limit    => l_high_batch_limit);
                print_log ('not Creating batch');
                print_log ('directly submitting the load program');
                print_log ('truncating mtl_system_items_interface table');

                --EXECUTE IMMEDIATE 'TRUNCATE TABLE INV.mtl_system_items_interface';

                l_request_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDCONV',
                        --Submitting Child Requests
                        program       => 'XXD_ITEM_LOAD_WRK',
                        argument1     => p_organization_code,
                        argument2     => 123,
                        argument3     => 123);
                lb_wait   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_request_id,
                        INTERVAL     => 1,
                        max_wait     => 1,
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);

                IF (lb_wait)
                THEN
                    print_log ('load done');
                END IF;
            END;

            print_log ('Call Procedure update_results_prc ');

            FOR c1_rec IN c1 (l_low_batch_limit, l_high_batch_limit)
            LOOP
                SELECT COUNT (1)
                  INTO l_interface_rec_cnt
                  FROM mtl_system_items_interface
                 WHERE set_process_id = c1_rec.batch_number;

                print_log ('l_interface_rec_cnt : ' || l_interface_rec_cnt);

                IF l_interface_rec_cnt > 0
                THEN
                    update_results_prc (
                        p_organization_code   => c1_rec.organization_code,
                        p_batch_low_limit     => c1_rec.batch_number,
                        p_batch_high_limit    => c1_rec.batch_number,
                        x_err_msg             => l_err_msg,
                        x_err_code            => l_err_code);
                ELSE
                    print_log (
                           'The Following batch :  '
                        || c1_rec.batch_number
                        || ' is not loaded into interface table,Please correct the error and load it again.');
                END IF;
            END LOOP;
        ELSIF p_process_level = 'SUBMIT'
        THEN
            IF p_organization_code IS NOT NULL
            THEN
                BEGIN
                    print_log (
                           'Call Procedure submit_item_import (organization code) : '
                        || p_organization_code);

                    submit_item_import (
                        x_errbuf              => l_err_msg,
                        x_retcode             => l_err_code,
                        p_organization_code   => p_organization_code);
                    print_log (
                        'submit_item_import procedure completed sucessfully');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_retcode   := 2;
                        x_errbuf    := x_errbuf || SQLERRM;
                        print_log (
                               'Submitting Item import program  error'
                            || SQLERRM);
                END;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    :=
                   'OTHERS Exception in the Procedure val_load_main.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure val_load_main:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure val_load_main.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END extract_val_load_main;

    /*+=========================================================================================+
    | Procedure name                                                                                 |
    |     submit_batch_prc                                                                               |
    |                                                                                                |
    | DESCRIPTION                                                                                     |
    |Procedure submit_batch_prc is the worker program to be submitted for validation            |
    |process.                                                                                                 |
    +==========================================================================================*/
    PROCEDURE submit_batch_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_organization_code IN VARCHAR2
                                , p_batch_low_limit IN NUMBER, p_batch_high_limit IN NUMBER, p_brand IN VARCHAR2)
    IS
        --Variable declarations
        l_organization_id            NUMBER;
        l_master_organization_id     NUMBER;
        l_item_count                 NUMBER;
        l_item_tot_count             NUMBER := 0;
        l_err_msg                    VARCHAR2 (4000);
        l_err_code                   NUMBER;
        l_organization_code          VARCHAR2 (240);
        l_master_organization_code   VARCHAR2 (240);
        l_return                     BOOLEAN;
        l_validated_rec_cnt          NUMBER;
        l_errored_rec_cnt            NUMBER;
        l_total_rec_cnt              NUMBER;
        l_item_no                    VARCHAR2 (4000);
        recordstatussbp              VARCHAR2 (5);

        --Cursor for distinct Batch Number
        CURSOR c1 IS
            SELECT DISTINCT batch_number
              FROM xxd_item_conv_stg_t
             --            WHERE     batch_number BETWEEN p_batch_low_limit
             --                                       AND p_batch_high_limit;
             WHERE organization_code =
                   NVL (p_organization_code, organization_code);

        --         GROUP BY batch_number, organization_code;

        --Cursor to fetch records for Re-Validation
        CURSOR c2 (p_batch_no NUMBER)
        IS
            SELECT segment1, organization_code
              FROM xxd_item_conv_stg_t
             WHERE batch_number = p_batch_no AND record_status IN ('N', 'E');

        --Cursor to display the errored out records in the output.
        CURSOR c3 (p_batch_no NUMBER)
        IS
            SELECT record_id, item_number segment1, organization_code,
                   record_status, error_message
              FROM xxd_item_conv_stg_t
             WHERE batch_number = p_batch_no AND record_status = 'E';
    BEGIN
        print_log ('Procedure val_load_main');

        FOR c1_rec IN c1
        LOOP
            l_err_msg          := NULL;
            l_item_tot_count   := 0;
            print_log ('1');

            --If the item already avlbl in Master org,go for validation process.
            IF l_item_tot_count = 0
            THEN
                l_err_code   := NULL;
                l_err_msg    := NULL;
                --    print_log ('2');
                print_log (
                       'Call Procedure validate_records_prc (p_organization_code, Batch Number): '
                    || p_organization_code
                    || ':-'
                    || c1_rec.batch_number);

                validate_records_prc (
                    p_organization_code   => p_organization_code,
                    p_batch_no            => c1_rec.batch_number,
                    p_brand               => p_brand,
                    x_err_msg             => l_err_msg,
                    x_err_code            => l_err_code);

                --   print_log ('3');

                --If any of the batches failed in validation
                IF l_err_code = 2
                THEN
                    l_errored_rec_cnt   :=
                        get_record_count                --Errored record count
                                         (
                            p_organization_code   => p_organization_code,
                            p_batch_number        => c1_rec.batch_number,
                            p_record_status       => 'E');
                    l_validated_rec_cnt   :=
                        get_record_count              --Validated record count
                                         (
                            p_organization_code   => p_organization_code,
                            p_batch_number        => c1_rec.batch_number,
                            p_record_status       => 'V');
                    l_total_rec_cnt   :=
                        get_record_count                  --Total record count
                                         (
                            p_organization_code   => p_organization_code,
                            p_batch_number        => c1_rec.batch_number,
                            p_record_status       => NULL);
                    print_log (
                           'Total no of failed records in the Batch no :'
                        || c1_rec.batch_number
                        || ' is: '
                        || l_errored_rec_cnt
                        || ' Please check the output for more details.');
                    l_return   :=
                        fnd_concurrent.set_completion_status (
                            'WARNING',
                            'The following Program has errors.');
                ELSIF l_err_code IS NULL
                --If Validation related to batches are successful.
                THEN
                    l_validated_rec_cnt   :=
                        get_record_count              --Validated record count
                                         (
                            p_organization_code   => p_organization_code,
                            p_batch_number        => c1_rec.batch_number,
                            p_record_status       => 'V');
                    l_total_rec_cnt   :=
                        get_record_count                  --Total record count
                                         (
                            p_organization_code   => p_organization_code,
                            p_batch_number        => c1_rec.batch_number,
                            p_record_status       => NULL);

                    IF l_validated_rec_cnt > 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.output,
                               'All the Records in the Batch no :'
                            || c1_rec.batch_number
                            || ' are validated successfully');
                        fnd_file.put_line (
                            fnd_file.output,
                               'Total Validated Records: '
                            || l_validated_rec_cnt);

                        fnd_file.put_line (
                            fnd_file.output,
                            'Validated Records are inserted into interface table: ');

                        fnd_file.put_line (fnd_file.output,
                                           'Calling interface_load_proc : ');


                        IF l_err_code = 2
                        THEN
                            fnd_file.put_line (
                                fnd_file.output,
                                   'Error while inserting Records into interface table: '
                                || l_err_msg);
                        ELSE
                            NULL;
                        END IF;
                    END IF;
                END IF;

                fnd_file.put_line (
                    fnd_file.output,
                    'The Concurrent Program log output consists of:');
                fnd_file.put_line (
                    fnd_file.output,
                    '------------------------------------------------------');
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (
                    fnd_file.output,
                    'XX INV Item Conversion - Worker Validate Program');
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (
                    fnd_file.output,
                    'Date: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY'));
                fnd_file.put_line (fnd_file.output,
                                   'Batch No: ' || c1_rec.batch_number);
                fnd_file.put_line (
                    fnd_file.output,
                    'Concurrent Request Id: ' || lv_conc_request_id);
                fnd_file.put_line (
                    fnd_file.output,
                    'Organization Code: ' || p_organization_code);
                fnd_file.put_line (fnd_file.output,
                                   'Batch Low Limit: ' || p_batch_low_limit);
                fnd_file.put_line (
                    fnd_file.output,
                    'Batch High Limit: ' || p_batch_high_limit);
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (
                    fnd_file.output,
                    'Organization code     Total Number of Records      Total Records Valid    Total Error Records ');
                fnd_file.put_line (
                    fnd_file.output,
                    '---------------------------------------------------------------------------------------------------------- ');
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (p_organization_code, 17, ' ')
                    || '     '
                    || LPAD (l_total_rec_cnt, 12, ' ')
                    || '      '
                    || LPAD (l_validated_rec_cnt, 18, ' ')
                    || '      '
                    || LPAD (l_errored_rec_cnt, 20, ' '));
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (fnd_file.output, 'Errors: ');
                fnd_file.put_line (fnd_file.output, ' ');
                fnd_file.put_line (
                    fnd_file.output,
                    'Process Row ID      Item Number    Organization Code   Error Code   Error Message');
                fnd_file.put_line (
                    fnd_file.output,
                    '---------------------------------------------------------------------------------------------------- ');

                FOR c3_rec IN c3 (c1_rec.batch_number)
                LOOP
                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (c3_rec.record_id, 21, ' ')
                        || ' '
                        || RPAD (c3_rec.segment1, 17, '  ')
                        || ' '
                        || RPAD (c3_rec.organization_code, 15, '      ')
                        || '      '
                        || RPAD (c3_rec.record_status, 6, '  ')
                        || ' '
                        || RPAD (c3_rec.error_message, 100, ' '));
                END LOOP;
            ELSE
                IF l_item_no IS NOT NULL
                THEN
                    l_item_no   := TRIM (',' FROM l_item_no);
                    print_log (
                           'The Following Item(s) '
                        || l_item_no
                        || ' doesnt exist in the Master Organization. ');
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            l_err_msg   :=
                   'OTHERS Exception in the Procedure submit_batch_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            x_errbuf    := l_err_msg;
            print_log (l_err_msg);
    END submit_batch_prc;

    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     interface_load_prc                                                                    |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    |Procedure interface_load_prc is to load the validated records from the staging table to    |
    |the interface table.                                                                       |
    +==========================================================================================*/
    PROCEDURE interface_load_prc (
        x_errbuf                 OUT NOCOPY VARCHAR2,
        x_retcode                OUT NOCOPY NUMBER,
        p_organization_code   IN            VARCHAR2,
        p_batch_low_limit     IN            NUMBER,
        p_batch_high_limit    IN            NUMBER)
    IS
        --Cursor to fetch the validated records
        CURSOR c1 IS
            SELECT DISTINCT batch_number
              FROM xxd_item_conv_stg_t
             WHERE     1 = 1
                   --                  AND     batch_number BETWEEN p_batch_low_limit
                   --                                       AND p_batch_high_limit
                   AND record_status = 'V'
                   --AND inventory_item_id = 11121327 --Srini
                   AND organization_code =
                       NVL (p_organization_code, organization_code);

        --         GROUP BY batch_number;

        CURSOR C2 IS SELECT max_item_id FROM xxd_item_conv_stg_t;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id     hdr_batch_id_t;


        ln_max_item_id      NUMBER;
        l_item_id           NUMBER;
        ln_cntr             NUMBER := 0;
        lx_set_process_id   NUMBER := 0;
    BEGIN
        FOR c1_rec IN c1
        LOOP
            BEGIN
                --         print_log ('batch_number : ' || c1_rec.batch_number);
                print_log ('Procedure interface_load_prc');
                print_log (
                    'Inserting to interface table mtl_system_items_interface');

                --ln_max_item_id := c1_rec.max_item_id;
                lx_set_process_id           := c1_rec.batch_number;
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := lx_set_process_id;


                INSERT INTO mtl_system_items_interface (
                                inventory_item_id,
                                organization_code,
                                organization_id,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                last_update_login,
                                transaction_id,
                                transaction_type,
                                description,
                                buyer_id,
                                segment1,
                                attribute_category,
                                attribute1,
                                attribute2,
                                attribute3,
                                attribute4,
                                attribute5,
                                attribute6,
                                attribute7,
                                attribute8,
                                attribute9,
                                attribute10,
                                attribute11,
                                attribute12,
                                attribute13,
                                attribute14,
                                attribute15,
                                list_price_per_unit,
                                unit_weight,
                                weight_uom_code,
                                volume_uom_code,
                                unit_volume,
                                primary_uom_code,
                                primary_unit_of_measure,
                                cost_of_sales_account,
                                sales_account,
                                inventory_item_status_code,
                                planner_code,
                                postprocessing_lead_time,
                                full_lead_time,
                                return_inspection_requirement,
                                process_flag,
                                MATERIAL_SUB_ELEM,
                                item_number,
                                template_id,
                                set_process_id,
                                long_description,
                                dimension_uom_code,
                                unit_length,
                                unit_width,
                                unit_height,
                                attribute16,
                                attribute17,
                                attribute18,
                                attribute19,
                                attribute20,
                                attribute21,
                                attribute22,
                                attribute23,
                                attribute24,
                                attribute25,
                                attribute26,
                                attribute27,
                                attribute28,
                                attribute29,
                                attribute30                         --REVISION
                                           )
                    --Start modification for BT dated 09-DEC-2014
                    SELECT inventory_item_id, organization_code, organization_id,
                           last_update_date, last_updated_by, creation_date,
                           created_by, last_update_login, NULL,
                           'CREATE', DECODE (p_organization_code, 'MST', REPLACE (description, CHR (15712189), ' ')), buyer_id,
                           ITEM_NUMBER, attribute_category, attribute1,
                           attribute2, attribute3, attribute4,
                           attribute5, attribute6, attribute7,
                           attribute8, attribute9, attribute10,
                           attribute11, attribute12, attribute13,
                           attribute14, attribute15, list_price_per_unit,
                           DECODE (p_organization_code, 'MST', unit_weight), DECODE (p_organization_code, 'MST', weight_uom_code), DECODE (p_organization_code, 'MST', volume_uom_code),
                           DECODE (p_organization_code, 'MST', unit_volume), DECODE (p_organization_code, 'MST', primary_uom_code), DECODE (p_organization_code, 'MST', primary_unit_of_measure),
                           cost_of_sales_account, sales_account, inventory_item_status_code,
                           planner_code, postprocessing_lead_time, full_lead_time,
                           DECODE (p_organization_code, 'MST', 2), 1, 'MATERIAL',
                           item_number, template_id, lx_set_process_id,
                           DECODE (p_organization_code, 'MST', long_description), DECODE (organization_code, 'MST', dimension_uom_code), --dimension_uom_code,
                                                                                                                                         DECODE (organization_code, 'MST', unit_length),
                           DECODE (organization_code, 'MST', unit_width), DECODE (organization_code, 'MST', unit_height), INTR_SEASON,
                           attribute17, attribute18, attribute19,
                           attribute20, attribute21, attribute22,
                           attribute23, attribute24, attribute25,
                           attribute26, attribute27, attribute28,
                           attribute29, attribute30
                      --0 REVISION
                      FROM xxd_item_conv_stg_t
                     WHERE     batch_number = c1_rec.batch_number
                           AND record_status = 'V' --and inventory_item_id = 11121327
                                                  ;

                print_log ('Record Count : ' || SQL%ROWCOUNT);

                UPDATE xxd_item_conv_stg_t
                   SET record_status   = 'P'
                 WHERE     batch_number = c1_rec.batch_number
                       AND record_status = 'V';
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE xxd_item_conv_stg_t
                       SET record_status   = 'E'
                     WHERE     batch_number = c1_rec.batch_number
                           AND record_status = 'V';

                    x_errbuf   :=
                           'OTHERS Exception in the Procedure interface_load_prc.  '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499);
                    print_log (
                           'OTHERS Exception in the Procedure interface_load_prc:  '
                        || SUBSTR (SQLERRM, 1, 499));
                    xxd_common_utils.record_error (
                        'INV',
                        xxd_common_utils.get_org_id,
                        'XXD INV Item Conversion - Worker Load Program',
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        fnd_profile.VALUE ('USER_ID'),
                        lv_conc_request_id,
                           'OTHERS Exception in the Procedure interface_load_prc.  '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499));
            END;
        END LOOP;

        COMMIT;
    /*     --Changing sequence for Inventory item id
         OPEN C2;

         ln_max_item_id := NULL;

         FETCH C2 INTO ln_max_item_id;

         CLOSE C2;

         --  fnd_file.put_line (fnd_file.LOG, 'ln_max_item_id ' || ln_max_item_id);

         LOOP
            SELECT MTL_SYSTEM_ITEMS_B_S.NEXTVAL INTO l_item_id FROM DUAL;

            --   fnd_file.put_line (fnd_file.LOG, 'l_item_id ' || l_item_id);

            IF l_item_id > ln_max_item_id
            THEN
               EXIT;
            END IF;
         END LOOP; */
    ----------------
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 3;
            x_errbuf    :=
                   'OTHERS Exception in the Procedure interface_load_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure interface_load_prc:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Worker Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure interface_load_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END interface_load_prc;

    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     batch_update_prc                                                                      |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    |Procedure batch_update_prc calculates number of batch number to be updated for records     |
    |based on batch size passed as parameter and updates the same.                              |
    +==========================================================================================*/
    PROCEDURE batch_update_prc (p_organization_code   IN VARCHAR2,
                                p_batch_size          IN NUMBER)
    IS
        l_batch_no          NUMBER;
        l_batch_cnt         NUMBER;
        l_rec_cnt           NUMBER;
        l_batch_size        NUMBER := 0;
        l_organization_id   NUMBER := 0;

        --Cursor to fetch records to be updated with batch number
        CURSOR c1 (p_batch_sz IN NUMBER, p_organization_id NUMBER)
        IS
            SELECT *
              FROM xxd_item_conv_stg_t
             WHERE     record_status = 'N'
                   AND organization_id = p_organization_id
                   AND ROWNUM <= p_batch_sz;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Procedure batch_update_prc');
        --  GET_ORG_ID(p_organization_code, l_organization_id);

        --Calculate total no of batch numbers
        l_rec_cnt     :=
            calc_eligible_records (p_organization_code => p_organization_code);
        l_batch_cnt   := CEIL (l_rec_cnt / p_batch_size);

        FOR i IN 1 .. l_batch_cnt
        LOOP
            l_batch_size   := l_batch_size + p_batch_size;

            SELECT xxd_item_conv_bth_seq.NEXTVAL INTO l_batch_no FROM DUAL;

            FOR c1_rec IN c1 (l_batch_size, l_organization_id)
            LOOP
                --FND_FILE.put_line( 'record_no '||c1_rec.record_no);
                UPDATE xxd_item_conv_stg_t
                   --Staging table updated with Batch Number
                   SET batch_number   = l_batch_no
                 WHERE record_id = c1_rec.record_id AND batch_number IS NULL;
            END LOOP;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'OTHERS Exception in the Procedure batch_update_prc:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure batch_update_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END batch_update_prc;

    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     create_batch_prc                                                                      |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    |Procedure create_batch_prc generated batch numbers for the records in the                  |
    |staging table                                                                              |
    +==========================================================================================*/
    PROCEDURE create_batch_prc (p_organization_code IN VARCHAR2, p_batch_size IN NUMBER, x_err_msg OUT VARCHAR2
                                , x_err_code OUT NUMBER)
    IS
        --Cursor to fetch distinct organization code
        CURSOR c1 (p_organization_id NUMBER)
        IS
              SELECT organization_code
                FROM xxd_item_conv_stg_t
               WHERE     record_status = 'N'
                     AND organization_id =
                         NVL (p_organization_id, organization_id)
            GROUP BY organization_code;

        l_organization_id   NUMBER;
    BEGIN
        print_log ('Procedure create_batch_prc');
        get_org_id_1206 (p_organization_code, l_organization_id);

        FOR c1_rec IN c1 (l_organization_id)
        LOOP
            print_log ('Calling batch_update_prc');
            batch_update_prc (
                p_organization_code   => c1_rec.organization_code,
                p_batch_size          => p_batch_size);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_code   := 2;
            x_err_msg    :=
                   'OTHERS Exception in the Procedure create_batch_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure create_batch_prc:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure create_batch_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END create_batch_prc;

    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     update_results_prc                                                                    |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    |Procedure update_results_prc updates the record status of the validated records inserted   |
    |into the interface table with 'L'                                                          |
    +==========================================================================================*/
    PROCEDURE update_results_prc (p_organization_code   IN     VARCHAR2,
                                  p_batch_low_limit     IN     NUMBER,
                                  p_batch_high_limit    IN     NUMBER,
                                  x_err_msg                OUT VARCHAR2,
                                  x_err_code               OUT NUMBER)
    IS
        --Cursor to fetch the row_id of the validated records from staging table.
        CURSOR c1 IS
            SELECT ROWID row_id
              FROM xxd_item_conv_stg_t
             WHERE     batch_number BETWEEN p_batch_low_limit
                                        AND p_batch_high_limit
                   AND organization_code =
                       NVL (p_organization_code, organization_code)
                   AND record_status = 'V';

        TYPE gt_item_conv_stg IS TABLE OF VARCHAR2 (240)
            INDEX BY BINARY_INTEGER;

        gt_success_rowid   gt_item_conv_stg;
    BEGIN
        print_log ('Procedure update_results_prc');

        OPEN c1;

        FETCH c1 BULK COLLECT INTO gt_success_rowid;

        CLOSE c1;

        FORALL i IN gt_success_rowid.FIRST .. gt_success_rowid.LAST
            UPDATE xxd_item_conv_stg_t     --Updates the record_status as 'P''
               SET record_status   = 'P'
             WHERE ROWID = gt_success_rowid (i);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_code   := 2;
            x_err_msg    :=
                   'OTHERS Exception in the Procedure update_results_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (
                   'OTHERS Exception in the Procedure update_results_prc:  '
                || SUBSTR (SQLERRM, 1, 499));
            xxd_common_utils.record_error (
                'INV',
                xxd_common_utils.get_org_id,
                'XXD INV Item Conversion - Validate and Load Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'),
                lv_conc_request_id,
                   'OTHERS Exception in the Procedure update_results_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499));
    END update_results_prc;

    PROCEDURE get_brand_dept (p_item_id IN NUMBER, x_dept OUT VARCHAR2, x_ret_brand_value OUT VARCHAR2
                              , x_ret_brand_id OUT NUMBER)
    IS
        CURSOR get_brand_c (p_item_id NUMBER)
        IS
            SELECT segment1, segment3
              FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                   org_organization_definitions ood
             WHERE     mic.organization_id = ood.organization_id
                   AND organization_code = 'MST'
                   AND inventory_item_id = p_item_id
                   AND mic.category_set_id = mcs.category_set_id
                   AND mcs.category_set_name = 'Inventory'
                   AND mc.category_id = mic.category_id;

        lc_brand             VARCHAR2 (100);
        lc_brand_value       VARCHAR2 (15);
        lc_ret_brand_value   VARCHAR2 (250);
    BEGIN
        OPEN get_brand_c (p_item_id);

        x_ret_brand_value   := NULL;
        x_dept              := NULL;

        FETCH get_brand_c INTO x_ret_brand_value, x_dept;

        CLOSE get_brand_c;

        SELECT ffv.FLEX_VALUE
          INTO x_ret_brand_id
          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
         WHERE     flex_value_set_name = 'DO_GL_BRAND'
               AND ffvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
               AND UPPER (ffv.DESCRIPTION) = UPPER (x_ret_brand_value);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            prt_log (gc_debug_flag, 'get_brand_dept   ' || SQLERRM);
        WHEN OTHERS
        THEN
            prt_log (gc_debug_flag, 'get_brand_dept   ' || SQLERRM);
    END get_brand_dept;



    PROCEDURE derive_planner_code (p_brand IN VARCHAR2, p_organization_id IN NUMBER, x_planner_code OUT VARCHAR2)
    IS
        CURSOR get_palnner_code_c (p_brand             VARCHAR2,
                                   p_organization_id   NUMBER)
        IS
            SELECT flv.meaning
              FROM fnd_lookup_values flv, mtl_parameters mp, mtl_planners mpl
             WHERE     flv.tag = p_brand
                   AND flv.lookup_type = 'DO_PLANNER_CODE'
                   AND flv.enabled_flag = 'Y'
                   AND mpl.PLANNER_CODE = UPPER (flv.meaning)
                   AND mpl.organization_id = mp.organization_id
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND mp.organization_id = p_organization_id
                   AND (flv.DESCRIPTION = mp.attribute1 OR mp.attribute1 IS NULL);

        --      lcu_Get_palnner_code_c        Get_palnner_code_c%ROWTYPE;

        lc_planner_code   VARCHAR2 (100) := NULL;
    BEGIN
        --prt_log (gc_debug_flag, 'Planner p_brand   ' || p_brand);

        --prt_log (gc_debug_flag,               'Planner p_organization_id   ' || p_organization_id);

        OPEN Get_palnner_code_c (p_brand, p_organization_id);

        --lcu_Get_palnner_code_c := NULL;

        FETCH Get_palnner_code_c INTO lc_planner_code;

        CLOSE Get_palnner_code_c;

        IF lc_planner_code IS NULL
        THEN
            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Inventory Organization Update Program', --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => SUBSTR (SQLERRM, 1, 2000),         --SQLERRM
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'Item id  ',
                --|| gtt_inv_item_attr_t (i).Inventory_item_id, --additional information for troubleshooting
                p_more_info2   => 'Organization id  ' || p_organization_id, --additional information for troubleshooting
                p_more_info3   => 'Could not derive Planner code ');
        END IF;

        x_planner_code   := UPPER (lc_planner_code);

        prt_log (gc_debug_flag, 'Planner code   ' || lc_planner_code);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            prt_log (gc_debug_flag, 'Planner code   ' || SQLERRM);
        WHEN OTHERS
        THEN
            prt_log (gc_debug_flag, 'Planner code   ' || SQLERRM);
    END derive_planner_code;



    PROCEDURE derive_org_accounts (p_organization_id IN NUMBER, x_sales_account OUT NUMBER, x_cogs_account OUT NUMBER)
    IS
        CURSOR get_account_c (p_organization_id IN NUMBER)
        IS
            SELECT SALES_ACCOUNT, COST_OF_SALES_ACCOUNT
              FROM mtl_parameters mp
             WHERE organization_id = p_organization_id;

        lcu_get_account_c   get_account_c%ROWTYPE;
    BEGIN
        lcu_get_account_c   := NULL;

        OPEN get_account_c (p_organization_id);

        --LOOP
        FETCH get_account_c INTO x_sales_account, x_cogs_account;

        CLOSE get_account_c;

        --prt_log (         gc_debug_flag,         'Sales account id for the org ' || lcu_get_account_c.SALES_ACCOUNT);
        --prt_log (         gc_debug_flag,            'Cost of sales account id for the org '         || lcu_get_account_c.COST_OF_SALES_ACCOUNT);



        IF (lcu_get_account_c.sales_account IS NULL OR lcu_get_account_c.cost_of_sales_account IS NULL)
        THEN
            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Inventory Organization Update Program', --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => SUBSTR (SQLERRM, 1, 2000),         --SQLERRM
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'Item id  ', --additional information for troubleshooting
                p_more_info2   => 'Organization id  ' || p_organization_id, --additional information for troubleshooting
                p_more_info3   =>
                    'Sales account or cost of sales account is null ');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END derive_org_accounts;



    PROCEDURE derive_templet_id (p_organization_id   IN     NUMBER,
                                 x_template_id          OUT NUMBER)
    IS
        CURSOR get_template_id_c (p_organization_id NUMBER)
        IS
            SELECT template_id
              FROM fnd_lookup_values flv, mtl_item_templates mit, org_organization_definitions ood
             WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND flv.description = mit.template_name
                   AND ood.organization_code = SUBSTR (flv.lookup_code, 1, 3)
                   AND ood.organization_id = p_organization_id;
    --      ln_template_id               NUMBER;

    BEGIN
        x_template_id   := NULL;

        OPEN Get_template_id_c (p_organization_id);

        x_template_id   := NULL;

        FETCH Get_template_id_c INTO x_template_id;

        CLOSE Get_template_id_c;

        IF x_template_id IS NULL
        THEN
            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Inventory Organization Update Program', --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => SUBSTR (SQLERRM, 1, 2000),         --SQLERRM
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'Item id  ', --additional information for troubleshooting
                p_more_info2   => 'p_organization_id   ' || p_organization_id, --additional information for troubleshooting
                p_more_info3   => 'Could not derive Templet ');
        END IF;
    --prt_log (gc_debug_flag, 'Template id  ' || x_template_id);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END derive_templet_id;



    PROCEDURE derive_lead_time (p_organization_id   IN     NUMBER,
                                x_pp_lead_time         OUT VARCHAR2)
    IS
        CURSOR get_ppt_time_c (p_org_id NUMBER)
        IS
            SELECT Description
              FROM fnd_lookup_values flv, org_organization_definitions ood
             WHERE     lookup_type = 'DO_POST_PROCESSING'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND ood.organization_code = flv.lookup_code
                   AND organization_id = p_org_id;
    BEGIN
        OPEN get_ppt_time_c (p_organization_id);

        x_pp_lead_time   := NULL;

        FETCH get_ppt_time_c INTO x_pp_lead_time;

        CLOSE get_ppt_time_c;


        IF x_pp_lead_time IS NULL
        THEN
            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Inventory Organization Update Program', --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => SUBSTR (SQLERRM, 1, 2000),         --SQLERRM
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'Item id  ',
                --|| gtt_inv_item_attr_t (i).Inventory_item_id, --additional information for troubleshooting
                p_more_info2   => 'Organization id  ' || p_organization_id, --additional information for troubleshooting
                p_more_info3   => 'Could not derive Post processing time ');
        END IF;
    --prt_log (gc_debug_flag,               'derive Post processing time   ' || x_pp_lead_time);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END derive_lead_time;



    PROCEDURE derive_buyer (p_brand IN VARCHAR2, p_dept IN VARCHAR2, p_organization_id IN NUMBER
                            , x_buyer_id OUT NUMBER)
    IS
        CURSOR Get_buyer_id_c (p_brand    VARCHAR2,
                               p_dept     VARCHAR2,
                               p_org_id   NUMBER)
        IS
            SELECT agent_id                                        --, flv.tag
              --INTO lc_region, lc_buyer, lc_dept1
              FROM fnd_lookup_values flv, per_all_people_f ppf, po_agents pa,
                   mtl_parameters mp
             WHERE     flv.attribute1 = p_brand
                   AND lookup_type = 'DO_BUYER_CODE'
                   --AND ( (flv.attribute2 = p_dept) OR flv.attribute2 IS NULL)
                   AND ((flv.attribute2 = p_dept) OR flv.attribute2 = 'ALL')
                   --DECODE (flv.attribute2, 'ALL', 'ALL', p_dept)
                   AND ppf.full_name = DESCRIPTION
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   ppf.effective_start_date)
                                           AND TRUNC (
                                                   NVL (
                                                       ppf.effective_end_date,
                                                       SYSDATE))
                   AND ((NVL (mp.attribute1, flv.tag) = flv.tag) OR NVL (mp.attribute1, 'XX') = NVL (flv.tag, 'XX') OR NVL (flv.tag, mp.attribute1) = mp.attribute1)
                   AND pa.agent_id = ppf.person_id
                   AND mp.organization_id = p_org_id;
    --      ln_buyer_id                   NUMBER;

    BEGIN
        x_buyer_id   := NULL;

        --prt_log (gc_debug_flag, 'p_brand  ' || p_brand);
        --prt_log (gc_debug_flag, 'p_dept  ' || p_dept);
        --prt_log (gc_debug_flag, 'p_organization_id  ' || p_organization_id);

        OPEN Get_buyer_id_c (p_brand, p_dept, p_organization_id);

        x_buyer_id   := NULL;

        FETCH Get_buyer_id_c INTO x_buyer_id;

        CLOSE Get_buyer_id_c;

        IF x_buyer_id IS NULL
        THEN
            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => 'Deckers Inventory Organization Update Program', --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => SUBSTR (SQLERRM, 1, 2000),         --SQLERRM
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'Item id  ', --additional information for troubleshooting
                p_more_info2   => 'Organization id  ' || p_organization_id, --additional information for troubleshooting
                p_more_info3   => 'Could not derive buyer ');
        END IF;
    --prt_log (gc_debug_flag, 'Buyer id  ' || x_buyer_id);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END derive_buyer;


    PROCEDURE get_conc_code_combn (p_code_combn_id IN NUMBER, p_brand IN VARCHAR2, x_new_ccid OUT NUMBER)
    IS
        CURSOR get_conc_code_combn_c IS
            SELECT segment1, NVL (p_brand, segment2), segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              FROM gl_code_combinations
             WHERE code_combination_id = p_code_combn_id;

        lc_conc_code_combn   VARCHAR2 (100);
        l_n_segments         NUMBER := 8;
        l_delim              VARCHAR2 (1) := '.';
        l_segment_array      FND_FLEX_EXT.SegmentArray;
        ln_coa_id            NUMBER;
        l_concat_segs        VARCHAR2 (32000);
    BEGIN
        --prt_log (gc_debug_flag, 'p_code_combn_id(1)   ' || p_code_combn_id);
        --prt_log (gc_debug_flag, 'p_brand(1)   ' || p_brand);

        OPEN get_conc_code_combn_c;

        FETCH get_conc_code_combn_c
            INTO l_segment_array (1), l_segment_array (2), l_segment_array (3), l_segment_array (4),
                 l_segment_array (5), l_segment_array (6), l_segment_array (7),
                 l_segment_array (8);

        CLOSE get_conc_code_combn_c;

        --RETURN lc_conc_code_combn;

        --prt_log (gc_debug_flag, 'l_segment_array(1)   ' || l_segment_array (1));
        --prt_log (gc_debug_flag, 'l_segment_array(2)   ' || l_segment_array (2));
        --prt_log (gc_debug_flag, 'l_segment_array(3)   ' || l_segment_array (3));

        SELECT CHART_OF_ACCOUNTS_ID
          INTO ln_coa_id
          FROM gl_sets_of_books
         WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');

        --prt_log (gc_debug_flag, 'ln_coa_id    ' || ln_coa_id);

        l_concat_segs   :=
            fnd_flex_ext.concatenate_segments (l_n_segments,
                                               l_segment_array,
                                               l_delim);

        prt_log (gc_debug_flag, 'Concatinated Segments   ' || l_concat_segs);
        x_new_ccid   :=
            Fnd_Flex_Ext.get_ccid ('SQLGL',
                                   'GL#',
                                   ln_coa_id,
                                   TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                   l_concat_segs);

        --prt_log (gc_debug_flag, 'New CCID Segments   ' || x_new_ccid);

        IF x_new_ccid = 0
        THEN
            x_new_ccid   := p_code_combn_id;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            prt_log (gc_debug_flag, 'get_conc_code_combn   ' || SQLERRM);
        WHEN OTHERS
        THEN
            prt_log (gc_debug_flag, 'get_conc_code_combn   ' || SQLERRM);
    END get_conc_code_combn;


    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     validate_records_prc                                                                  |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    | Procedure validate_records_prc validates and derives the values to be updated to          |
    | the staging table.                                                                        |
    +==========================================================================================*/
    PROCEDURE validate_records_prc (p_organization_code   IN     VARCHAR2,
                                    p_batch_no            IN     NUMBER,
                                    p_brand               IN     VARCHAR2,
                                    x_err_msg                OUT VARCHAR2,
                                    x_err_code               OUT NUMBER)
    IS
        --Variable declarations
        l_organization_id            NUMBER;
        l_source_organization_id     NUMBER;
        l_record_error               NUMBER := 0;
        l_expense_account            NUMBER;
        l_encumbrance_account        NUMBER;
        l_cost_of_sales_account      NUMBER;
        l_sales_account              NUMBER;
        l_expense_account_no         VARCHAR2 (240);
        l_encumbrance_account_no     VARCHAR2 (240);
        l_cost_of_sales_account_no   VARCHAR2 (240);
        l_sales_account_no           VARCHAR2 (240);
        l_buyer_id                   NUMBER;
        l_catalog_group_id           NUMBER;
        l_item_count                 NUMBER;
        l_uom_code                   VARCHAR2 (240);
        l_error_msg                  VARCHAR2 (10000);
        l_bundle_id                  NUMBER
            := mtl_system_items_interface_s.NEXTVAL;
        xxd_item_duplication         EXCEPTION;
        lc_org_code                  VARCHAR2 (30);         --Added By Sryeruv
        l_def_cost_of_sales_acct     NUMBER;
        l_def_sales_acct             NUMBER;

        --x_dept                       VARCHAR2;
        --x_ret_brand_value            VARCHAR2;
        x_ret_brand_id               NUMBER;

        --Cusrsor to fetch the records which are to be validated
        CURSOR get_all_records (p_org_code VARCHAR)
        IS
            SELECT *
              FROM xxd_item_conv_stg_t
             WHERE     batch_number = p_batch_no
                   AND organization_code =
                       NVL (p_org_code, organization_code)
                   AND record_status IN ('N', 'E')   --AND record_id = 7080596
                                                  ;

        /*     CURSOR lcu_get_ccid_code (
                p_account_type    VARCHAR2,
                p_org_code        VARCHAR2,
                pbrand            VARCHAR2)
             IS
                SELECT XICS.code_combination
                  FROM xxd_item_cost_sales_acct XICS
                 WHERE     XICS.org_code = p_org_code
                       AND XICS.account_type = p_account_type
                       AND XICS.brand = pbrand; */

        CURSOR lcu_get_ccid (p_code VARCHAR2)
        IS
            SELECT code_combination_id
              FROM gl_code_combinations_kfv gcc
             WHERE gcc.enabled_flag = 'Y' AND concatenated_segments = p_code;

        CURSOR lcu_get_ccid1 (p_code_id NUMBER)
        IS
            SELECT concatenated_segments
              FROM gl_code_combinations_kfv gcc
             WHERE gcc.enabled_flag = 'Y' AND code_combination_id = p_code_id;


        lc_sample                    VARCHAR (100);
        lc_attribute28               VARCHAR (100);

        CURSOR Get_template_id_c (p_organization_id NUMBER, p_type VARCHAR2)
        IS
            SELECT template_id
              FROM fnd_lookup_values flv, mtl_item_templates mit, org_organization_definitions ood
             WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND flv.description = mit.template_name
                   AND ood.organization_code = SUBSTR (flv.lookup_code, 1, 3)
                   AND ood.organization_id = p_organization_id
                   AND Tag = p_type
                   AND ROWNUM = 1;


        ln_template_id               NUMBER;

        CURSOR get_org_id_c IS
            SELECT Organization_id
              FROM org_organization_definitions
             WHERE organization_code = p_organization_code;

        lx_organization_id           NUMBER;

        /* Cursor get_lpu_flt_c(p_inventory_item_id NUMBER) IS
         SELECT LIST_PRICE_PER_UNIT, FULL_LEAD_TIME
                FROM XXD_CONV.XXD_ITEM_CONV_1206_T_RUN_BKP XTB ,FND_LOOKUP_VALUES FLV
               WHERE     inventory_item_id = p_inventory_item_id
               AND FLV.attribute1 = p_organization_code
                AND organization_id = lookup_code;

           ln_LIST_PRICE_PER_UNIT        NUMBER;
           ln_FULL_LEAD_TIME   NUMBER; */


        CURSOR get_temp_id_c IS
            SELECT template_id
              FROM mtl_item_templates
             WHERE template_name = 'MST-CUSTOM-ATO';

        ln_temp_id                   NUMBER;

        lc_ret_brand_value           VARCHAR2 (250);
        lc_ret_brand_id              NUMBER;
        lc_dept_value                VARCHAR2 (250);

        lx_sales_account             VARCHAR2 (3500);
        lx_cogs_account              VARCHAR2 (3500);
        lx_template_id               NUMBER;
        lx_pp_lead_time              VARCHAR2 (250);
        ln_buyer_id                  NUMBER;
        lc_planner_code              VARCHAR2 (100);
        ln_sales_account             NUMBER;
        ln_cost_of_sales_account     NUMBER;

        --List Price Change
        CURSOR Get_list_price_c (p_item_id NUMBER)
        IS
            SELECT MAX (LIST_PRICE_PER_UNIT)
              FROM xxd_item_conv_stg_t
             WHERE     organization_id IN (107, 108, 109)
                   AND inventory_item_id = p_item_id;

        ln_LIST_PRICE_PER_UNIT       NUMBER;

        CURSOR Get_currency_code_c (p_org_code VARCHAR2)
        IS
            SELECT currency_code
              FROM org_organization_definitions ood, gl_sets_of_books gsb
             WHERE     ood.SET_OF_BOOKS_ID = gsb.SET_OF_BOOKS_ID
                   AND organization_code = p_org_code;

        lc_currency_code             VARCHAR2 (10);

        CURSOR Get_lead_time_c (p_org_code VARCHAR2)
        IS
            SELECT TO_NUMBER (description) description
              FROM fnd_lookup_values
             WHERE     lookup_type = 'DO_ADD_CUMM_LEAD_TIME'
                   AND language = 'US'
                   AND meaning = p_org_code;

        ln_desc                      NUMBER;


        CURSOR get_conv_rate_c (p_curr_code VARCHAR2)
        IS
            SELECT SHOW_CONVERSION_RATE
              FROM GL_DAILY_RATES_V
             WHERE     USER_CONVERSION_TYPE = 'Corporate'
                   AND TRUNC (CONVERSION_DATE) LIKE TRUNC (SYSDATE)
                   AND from_currency = 'USD'
                   AND to_currency = p_curr_code;

        ln_conv_rate                 NUMBER;
        lc_WEIGHT_UOM_CODE           VARCHAR2 (3);
        lc_VOLUME_UOM_CODE           VARCHAR2 (3);
        lc_DIMENSION_UOM_CODE        VARCHAR2 (3);
    BEGIN
        print_log (
               'Procedure validate_records_prc: '
            || 'Batch#:'
            || p_batch_no
            || ' Organization_Code:'
            || p_organization_code);

        --fnd_file.put_line (         fnd_file.LOG,         'ln_LIST_PRICE_PER_UNIT1 ' || ln_LIST_PRICE_PER_UNIT);

        OPEN get_org_id_c;

        lx_organization_id   := NULL;

        FETCH get_org_id_c INTO lx_organization_id;

        CLOSE get_org_id_c;

        --Start modification on 05-OCT-2015
        --ATO Template Update
        OPEN get_temp_id_c;

        ln_temp_id           := NULL;

        FETCH get_temp_id_c INTO ln_temp_id;

        CLOSE get_temp_id_c;

        --ATO Template Update

        --End modification on 05-OCT-2015


        OPEN Get_currency_code_c (p_organization_code);

        lc_currency_code     := NULL;

        FETCH Get_currency_code_c INTO lc_currency_code;

        CLOSE Get_currency_code_c;


        OPEN Get_lead_time_c (p_organization_code);

        ln_desc              := NULL;

        FETCH Get_lead_time_c INTO ln_desc;

        CLOSE Get_lead_time_c;

        --fnd_file.put_line (fnd_file.LOG,                         'lc_currency_code ' || lc_currency_code);


        OPEN get_conv_rate_c (lc_currency_code);

        ln_conv_rate         := NULL;

        FETCH get_conv_rate_c INTO ln_conv_rate;

        CLOSE get_conv_rate_c;

        --fnd_file.put_line (fnd_file.LOG, 'ln_conv_rate ' || ln_conv_rate);

        --lx_organization_id := p_organization_id;

        IF p_organization_code <> 'MST'
        THEN
            lx_sales_account   := NULL;
            lx_cogs_account    := NULL;
            lx_template_id     := NULL;
            lx_pp_lead_time    := NULL;

            derive_org_accounts (p_organization_id   => lx_organization_id,
                                 x_sales_account     => lx_sales_account,
                                 x_cogs_account      => lx_cogs_account);

            derive_templet_id (p_organization_id   => lx_organization_id,
                               x_template_id       => lx_template_id);

            derive_lead_time (p_organization_id   => lx_organization_id,
                              x_pp_lead_time      => lx_pp_lead_time);
        END IF;



        --GET_ORG_ID(p_organization_code, l_organization_id);
        FOR c1_rec IN get_all_records (p_organization_code)
        LOOP
            l_record_error               := 0;
            l_error_msg                  := NULL;
            l_organization_id            := NULL;
            l_expense_account            := NULL;
            l_encumbrance_account        := NULL;
            l_sales_account              := NULL;
            l_cost_of_sales_account      := NULL;
            l_expense_account_no         := NULL;
            l_encumbrance_account_no     := NULL;
            l_cost_of_sales_account_no   := NULL;
            l_sales_account_no           := NULL;
            l_buyer_id                   := NULL;
            l_catalog_group_id           := NULL;
            l_item_count                 := 0;

            BEGIN
                --print_log ('Deriving org id -1-');

                --Deriving Organization Id
                SELECT organization_id
                  INTO l_organization_id
                  FROM mtl_parameters
                 WHERE organization_code = c1_rec.organization_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           'Error in Deriving Organization Id : '
                        || SUBSTR (SQLERRM, 1, 500);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
            --print_log (l_error_msg);
            END;


            /*       BEGIN
                      --print_log ('Deriving org id -1-');

                      --Deriving Organization Id
                      SELECT organization_id
                        INTO l_organization_id
                        FROM mtl_parameters
                       WHERE organization_code = c1_rec.organization_code;
                   EXCEPTION
                      WHEN OTHERS
                      THEN
                         l_record_error := l_record_error + 1;
                         l_error_msg :=
                               'Error in Deriving Organization Id : '
                            || SUBSTR (SQLERRM, 1, 500);
                         x_err_code := 2;
                         x_err_msg := l_error_msg;
                         --print_log (l_error_msg);
                   END;

           */



            --print_log ('Deriving org id -1-');
            lc_WEIGHT_UOM_CODE           := NULL;

            IF c1_rec.WEIGHT_UOM_CODE IS NOT NULL
            THEN
                --Deriving WEIGHT_UOM_CODE
                BEGIN
                    SELECT UOM_CODE
                      INTO lc_WEIGHT_UOM_CODE
                      FROM MTL_UNITS_OF_MEASURE
                     WHERE UOM_CODE = UPPER (c1_rec.WEIGHT_UOM_CODE);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_record_error   := l_record_error + 1;
                        l_error_msg      :=
                               l_error_msg
                            || '-'
                            || 'Error in Deriving WEIGHT_UOM_CODE : '
                            || SUBSTR (SQLERRM, 1, 500);
                        x_err_code       := 2;
                        x_err_msg        := l_error_msg;
                -- print_log (l_error_msg);
                END;
            END IF;

            lc_VOLUME_UOM_CODE           := NULL;

            IF c1_rec.VOLUME_UOM_CODE IS NOT NULL
            THEN
                --Deriving Volume_UOM_CODE
                BEGIN
                    SELECT UOM_CODE
                      INTO lc_VOLUME_UOM_CODE
                      FROM MTL_UNITS_OF_MEASURE
                     WHERE UOM_CODE = UPPER (c1_rec.VOLUME_UOM_CODE);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_record_error   := l_record_error + 1;
                        l_error_msg      :=
                               l_error_msg
                            || '-'
                            || 'Error in Deriving VOLUME_UOM_CODE : '
                            || SUBSTR (SQLERRM, 1, 500);
                        x_err_code       := 2;
                        x_err_msg        := l_error_msg;
                --print_log (l_error_msg);
                END;
            END IF;

            lc_DIMENSION_UOM_CODE        := NULL;

            IF c1_rec.DIMENSION_UOM_CODE IS NOT NULL
            THEN
                BEGIN
                    SELECT UOM_CODE
                      INTO lc_DIMENSION_UOM_CODE
                      FROM MTL_UNITS_OF_MEASURE
                     WHERE UOM_CODE = UPPER (c1_rec.DIMENSION_UOM_CODE);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_record_error   := l_record_error + 1;
                        l_error_msg      :=
                               l_error_msg
                            || '-'
                            || 'Error in Deriving DIMENSION_UOM_CODE : '
                            || SUBSTR (SQLERRM, 1, 500);
                        x_err_code       := 2;
                        x_err_msg        := l_error_msg;
                --print_log (l_error_msg);
                END;
            END IF;



            IF NVL (c1_rec.LIST_PRICE_PER_UNIT, 0) = 0
            THEN
                OPEN Get_list_price_c (c1_rec.inventory_item_id);

                ln_LIST_PRICE_PER_UNIT   := NULL;

                FETCH Get_list_price_c INTO ln_LIST_PRICE_PER_UNIT;

                CLOSE Get_list_price_c;

                IF lc_currency_code = 'USD'
                THEN
                    NULL;
                ELSE
                    ln_LIST_PRICE_PER_UNIT   :=
                          NVL (ln_conv_rate, 1)
                        * NVL (ln_LIST_PRICE_PER_UNIT, 0);
                END IF;
            ELSE
                ln_LIST_PRICE_PER_UNIT   := c1_rec.LIST_PRICE_PER_UNIT; --Added  on 17-OCT
            END IF;



            BEGIN
                --print_log ('Deriving Source org id -2-');

                IF c1_rec.source_organization_code IS NOT NULL
                THEN                         --Deriving Source Organization Id
                    SELECT organization_id
                      INTO l_source_organization_id
                      FROM mtl_parameters
                     WHERE organization_code =
                           c1_rec.source_organization_code;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Source Organization Id : '
                        || SUBSTR (SQLERRM, 1, 500);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
            --print_log (x_err_msg);
            END;

            /*  open get_lpu_flt_c(c1_rec.inventory_item_id);

              ln_LIST_PRICE_PER_UNIT        := NULL;
               ln_FULL_LEAD_TIME := NULL;


              fetch get_lpu_flt_c into ln_LIST_PRICE_PER_UNIT,ln_FULL_LEAD_TIME;

              close get_lpu_flt_c; */

            --Deriving Code Combination id for expense_account, encumbrance_account,cost_of_sales_account and sales_account and updating to staging table.
            --Deriving Expense Account Number
            BEGIN
                --print_log (               '-Deriving Code Combination id for expense_account, encumbrance_account,cost_of_sales_account and sales acc  -3-');

                /* Commented By Sryeruv
                 SELECT expense_account, encumbrance_account,
                       cost_of_sales_account, sales_account
                  INTO l_expense_account, l_encumbrance_account,
                       l_cost_of_sales_account, l_sales_account
                  FROM mtl_parameters
                 WHERE organization_id = l_organization_id;
                 */
                SELECT expense_account, encumbrance_account, organization_code,
                       cost_of_sales_account, sales_account
                  INTO l_expense_account, l_encumbrance_account, lc_org_code, l_def_cost_of_sales_acct,
                                        l_def_sales_acct
                  FROM mtl_parameters
                 WHERE organization_id = l_organization_id;

                SELECT concatenated_segments
                  INTO l_expense_account_no
                  FROM gl_code_combinations_kfv gcc
                 WHERE     gcc.enabled_flag = 'Y'
                       AND gcc.code_combination_id = l_expense_account;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Expense account number : '
                        || SUBSTR (SQLERRM, 1, 500);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
            --print_log (l_error_msg);
            END;

            IF l_encumbrance_account IS NOT NULL
            THEN
                --Deriving Encumbrance account number
                BEGIN
                    -- print_log ('Deriving Encumbrance account number  -4-');

                    SELECT concatenated_segments
                      INTO l_encumbrance_account_no
                      FROM gl_code_combinations_kfv gcc
                     WHERE     gcc.enabled_flag = 'Y'
                           AND gcc.code_combination_id =
                               l_encumbrance_account;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_record_error   := l_record_error + 1;
                        l_error_msg      :=
                               l_error_msg
                            || '-'
                            || 'Error in Deriving Encumbrance account number : '
                            || SUBSTR (SQLERRM, 1, 500);
                        x_err_code       := 2;
                        x_err_msg        := l_error_msg;
                --  print_log (l_error_msg);
                END;
            END IF;

            /* Code commented due to the code combination logic is changed
            IF l_cost_of_sales_account IS NOT NULL
            THEN
               --Deriving Cost of Sales account number
               BEGIN
                  print_log ('Deriving Cost of Sales account number  -5-');

                  SELECT concatenated_segments
                    INTO l_cost_of_sales_account_no
                    FROM gl_code_combinations_kfv gcc
                   WHERE gcc.enabled_flag = 'Y'
                     AND gcc.code_combination_id = l_cost_of_sales_account;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     l_record_error := l_record_error + 1;
                     l_error_msg :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Cost of Sales account number : '
                        || SUBSTR (SQLERRM, 1, 500);
                     x_err_code := 2;
                     x_err_msg := l_error_msg;
                     print_log (l_error_msg);
               END;
            END IF;

            IF l_sales_account IS NOT NULL
            THEN
               --Deriving Sales account number
               BEGIN
                  print_log ('Deriving Sales account number -6-');

                  SELECT concatenated_segments
                    INTO l_sales_account_no
                    FROM gl_code_combinations_kfv gcc
                   WHERE gcc.enabled_flag = 'Y'
                     AND gcc.code_combination_id = l_sales_account;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     l_record_error := l_record_error + 1;
                     l_error_msg :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Sales account number : '
                        || SUBSTR (SQLERRM, 1, 500);
                     x_err_code := 2;
                     x_err_msg := l_error_msg;
                     print_log (l_error_msg);
               END;
            END IF;
            */
            --Deriving Sales account number
            IF lc_org_code = 'MST'
            THEN
                lc_org_code   := 'US1';
            END IF;

            print_log (
                'Deriving Sales account number lc_org_code - ' || lc_org_code);

            /*OPEN lcu_get_ccid_code ('SALES', lc_org_code, p_brand);

            FETCH lcu_get_ccid_code INTO l_sales_account_no;

            CLOSE lcu_get_ccid_code; */

            print_log (
                   'Deriving Sales account number l_sales_account_no - '
                || l_sales_account_no);

            IF l_sales_account_no IS NOT NULL
            THEN
                OPEN lcu_get_ccid (l_sales_account_no);

                FETCH lcu_get_ccid INTO l_sales_account;

                CLOSE lcu_get_ccid;

                IF l_sales_account IS NULL
                THEN                                     -- temparory solution
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Sales account number : '
                        || SUBSTR (SQLERRM, 1, 500);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
                --print_log (l_error_msg);
                END IF;
            ELSE
                OPEN lcu_get_ccid1 (l_def_sales_acct);

                FETCH lcu_get_ccid1 INTO l_sales_account_no;

                CLOSE lcu_get_ccid1;

                l_sales_account   := l_def_sales_acct;
            END IF;

            --print_log (               'Actual Sales account number l_sales_account_no - '            || l_sales_account_no            || ' - l_sales_account '            || l_sales_account);

            --Deriving Cost of Sales account number
            /*         OPEN lcu_get_ccid_code ('COGS', lc_org_code, p_brand);

                     FETCH lcu_get_ccid_code INTO l_cost_of_sales_account_no;

                     CLOSE lcu_get_ccid_code;

                     print_log (
                           'Deriving Cost of Sales account number l_cost_of_sales_account_no - '
                        || l_cost_of_sales_account_no); */

            IF l_cost_of_sales_account_no IS NOT NULL
            THEN
                OPEN lcu_get_ccid (l_cost_of_sales_account_no);

                FETCH lcu_get_ccid INTO l_cost_of_sales_account;

                CLOSE lcu_get_ccid;

                IF l_cost_of_sales_account IS NULL
                THEN                                     -- temparory solution
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Cost of Sales account number : '
                        || SUBSTR (SQLERRM, 1, 500);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
                --    print_log (l_error_msg);
                END IF;
            ELSE
                OPEN lcu_get_ccid1 (l_def_cost_of_sales_acct);

                FETCH lcu_get_ccid1 INTO l_cost_of_sales_account_no;

                CLOSE lcu_get_ccid1;

                l_cost_of_sales_account   := l_def_cost_of_sales_acct;
            END IF;

            --print_log (               'Deriving Cost of Sales account number l_cost_of_sales_account_no - '            || l_cost_of_sales_account_no            || ' - l_cost_of_sales_account '            || l_cost_of_sales_account);


            --Deriving Buyer_id and updated to staging table.
            /*      BEGIN
                     IF c1_rec.buyer IS NOT NULL
                     THEN
                        print_log ('Deriving buyer_id -6-');

                        SELECT pa.agent_id
                          INTO l_buyer_id
                          FROM po_agents pa, per_all_people_f papf
                         WHERE     pa.agent_id = papf.person_id
                               AND papf.full_name = c1_rec.buyer
                               AND papf.employee_number IS NOT NULL
                               AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                                       AND papf.effective_end_date;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        print_log (' -7-');
                        l_record_error := l_record_error + 1;
                        l_error_msg :=
                              l_error_msg
                           || '-'
                           || 'Error in Deriving Buyer Id Information : '
                           || SQLERRM;
                        x_err_code := 2;
                        x_err_msg :=
                              'OTHERS Exception, Error in Deriving Buyer Id Information in the Procedure validate_records_prc.  '
                           || SUBSTR (
                                 'Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                                 1,
                                 499);
                        --print_log(  'OTHERS Exception, Error in Deriving Buyer Id Information in the Procedure validate_records_prc:  '||SUBSTR(SQLERRM,1,499));
                        xxd_common_utils.record_error (
                           'INV',
                           xxd_common_utils.get_org_id,
                           'XXD INV Item Conversion - Worker Validate Program',
                           SQLERRM,
                           DBMS_UTILITY.format_error_backtrace,
                           fnd_profile.VALUE ('USER_ID'),
                           lv_conc_request_id,
                              'OTHERS Exception, Error in Deriving Buyer Id Information in the Procedure validate_records_prc.  '
                           || SUBSTR (
                                 'Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                                 1,
                                 499));
                  END; */

            --Deriving item_catalog_group_id and updated to staging table.
            BEGIN
                IF c1_rec.item_catalog_group_name IS NOT NULL
                THEN
                    --          print_log (' -8-');

                    SELECT item_catalog_group_id
                      INTO l_catalog_group_id
                      FROM mtl_item_catalog_groups
                     WHERE segment1 = c1_rec.item_catalog_group_name;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Deriving Catalog Group Id Information : '
                        || SQLERRM;
                    x_err_code       := 2;
                    x_err_msg        :=
                           'OTHERS Exception, Error in Deriving Catalog Group Id Information in the Procedure validate_records_prc.  '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499);
                    --print_log(  'OTHERS Exception, Error in Deriving Catalog Group Id Information in the Procedure validate_records_prc:  '||SUBSTR(SQLERRM,1,499));
                    xxd_common_utils.record_error (
                        'INV',
                        xxd_common_utils.get_org_id,
                        'XX INV Item Conversion - Worker Validate Program',
                        SQLERRM,
                        DBMS_UTILITY.format_error_backtrace,
                        fnd_profile.VALUE ('USER_ID'),
                        lv_conc_request_id,
                           'OTHERS Exception,Error in Deriving Catalog Group Id Information in the Procedure validate_records_prc.  '
                        || SUBSTR (
                                  'Error: '
                               || TO_CHAR (SQLCODE)
                               || ':-'
                               || SQLERRM,
                               1,
                               499));
            END;

            --Validate for Item Duplication    -- Ramya Commenting to be removed
            /*   BEGIN
                  SELECT COUNT (1)
                    INTO l_item_count
                    FROM mtl_system_items_b
                   WHERE segment1 = c1_rec.segment1
                     AND organization_id = l_organization_id;

                  IF l_item_count > 0
                  THEN
                     RAISE XXD_item_duplication;
                  END IF;
               EXCEPTION
                  WHEN XXD_item_duplication
                  THEN
                     l_record_error := l_record_error + 1;
                     l_error_msg :=
                           l_error_msg
                        || '-'
                        || 'Error in Duplicate Item Validation : '
                        || SQLERRM;
                     x_err_code := 2;
                     x_err_msg :=
                           'OTHERS Exception, Error in  Duplicate Item Validation  in the Procedure validate_records_prc.  '
                        || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                                   1,
                                   499
                                  );
                     --print_log(  'OTHERS Exception, Error in  Duplicate Item Validation  in the Procedure validate_records_prc:  '||SUBSTR(SQLERRM,1,499));
                     XXD_common_utils.record_error
                        ('INV',
                         XXD_common_utils.get_org_id,
                         'XXD INV Item Conversion - Worker Validate Program',
                         SQLCODE,
                         SQLERRM,
                         DBMS_UTILITY.format_error_backtrace,

                         SYSDATE,
                         fnd_profile.VALUE ('USER_ID'),
                         lv_conc_request_id,
                            'OTHERS Exception,Error in Duplicate Item Validation in the Procedure validate_records_prc.  '
                         || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-'
                                    || SQLERRM,
                                    1,
                                    499
                                   )
                        );
               END; */
            -- Ramya Commenting to be removed
            --Deriving UOM code
            BEGIN
                --     print_log (' -9-');

                SELECT uom_code
                  INTO l_uom_code
                  FROM mtl_uom_conversions
                 WHERE uom_code = c1_rec.primary_uom_code AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_record_error   := l_record_error + 1;
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Error in Validating Primary UOM Code : '
                        || SUBSTR (SQLERRM, 1, 200);
                    x_err_code       := 2;
                    x_err_msg        := l_error_msg;
            --      print_log (l_error_msg);
            END;

            --Update all the derived values
            /*     BEGIN
                    print_log (' -10-');

                    UPDATE xxd_item_conv_stg_t
                       SET bundle_id = l_bundle_id,
                           organization_id = l_source_organization_id,
                           buyer_id = l_buyer_id,
                           item_catalog_group_id = l_catalog_group_id,
                           creation_date = SYSDATE,
                           created_by = fnd_global.user_id,
                           last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id,
                           last_update_login = fnd_global.login_id
                     WHERE record_id = c1_rec.record_id;
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       print_log (' -11-');
                       l_record_error := l_record_error + 1;
                       l_error_msg :=
                             l_error_msg
                          || '-'
                          || 'Error while updating the all records in the staging table  : '
                          || SUBSTR (SQLERRM, 1, 500);
                       x_err_code := 2;
                       x_err_msg := l_error_msg;
                       print_log (l_error_msg);
                 END; */


            /*   IF p_organization_code = 'MST'
               THEN  */
            lc_sample                    := NULL;


            --Start Modofied on 13-Apr-2015
            /*      IF c1_rec.segment2 = 'ALL' OR c1_rec.segment3 = 'ALL'
                  THEN
                     lc_sample := 'GENERIC';

                     OPEN Get_template_id_c (lx_organization_id, lc_sample);

                     ln_template_id := NULL;



                     FETCH Get_template_id_c INTO ln_template_id;

                     CLOSE Get_template_id_c;
                  END IF; */
            --End Modofied on 13-Apr-2015


            IF c1_rec.SAMPLE_ITEM = 'SAMPLE'
            THEN
                lc_sample        := 'SAMPLE';
                lc_attribute28   := 'SAMPLE';
            --Start Modofied on 13-Apr-2015

            /*   OPEN Get_template_id_c (lx_organization_id, lc_sample);

               ln_template_id := NULL;

               FETCH Get_template_id_c INTO ln_template_id;

               CLOSE Get_template_id_c; */
            --End Modofied on 13-Apr-2015

            END IF;

            --Start modification on 31-MAY-2015

            /*  IF     c1_rec.SAMPLE_ITEM = 'SAMPLE'
                 AND (SUBSTR (c1_rec.segment1, -1, 1) = 'L')
              THEN
                 lc_sample := 'SAMPLE' || '-L';


                 OPEN Get_template_id_c (lx_organization_id, c1_rec.SAMPLE_ITEM);

                 ln_template_id := NULL;


                 FETCH Get_template_id_c INTO ln_template_id;

                 CLOSE Get_template_id_c;
              END IF;

              IF     c1_rec.SAMPLE_ITEM = 'SAMPLE'
                 AND (SUBSTR (c1_rec.segment1, -1, 1) = 'R')
              THEN
                 lc_sample := 'SAMPLE' || '-R';

                 OPEN Get_template_id_c (lx_organization_id, c1_rec.SAMPLE_ITEM);

                 ln_template_id := NULL;



                 FETCH Get_template_id_c INTO ln_template_id;

                 CLOSE Get_template_id_c;
              END IF; */

            --End  modification on 31-MAY-2015

            IF     SUBSTR (c1_rec.segment1, 1, 1) = 'S'
               AND SUBSTR (c1_rec.segment1, -1, 1) = 'R'
            THEN
                lc_sample        := 'SAMPLE';
                lc_attribute28   := 'SAMPLE-R';
            END IF;

            IF     SUBSTR (c1_rec.segment1, 1, 1) = 'S'
               AND SUBSTR (c1_rec.segment1, -1, 1) = 'L'
            THEN
                lc_sample        := 'SAMPLE';
                lc_attribute28   := 'SAMPLE-L';
            END IF;

            IF SUBSTR (c1_rec.segment1, 1, 2) = 'BG'
            THEN
                lc_sample        := 'BGRADE';
                lc_attribute28   := 'BGRADE';
            END IF;

            /*  IF SUBSTR (c1_rec.segment1, -2, 2) = 'BG'
              THEN */


            --IF c1_rec.SAMPLE_ITEM = 'BGRADE'          THEN             lc_sample := 'BGRADE';  Commented on 31-MAY-2015



            --END IF;     Commented on 31-MAY-2015

            IF lc_sample IS NULL
            THEN
                lc_sample        := 'PROD';
                lc_attribute28   := 'PROD';
            /*         OPEN Get_template_id_c (lx_organization_id, lc_sample);

                     ln_template_id := NULL;


                     FETCH Get_template_id_c INTO ln_template_id;

                     CLOSE Get_template_id_c; */
            END IF;

            --fnd_file.put_line (fnd_file.LOG,                            'attribute27 ' || c1_rec.attribute27);

            --fnd_file.put_line(fnd_file.log,'attribute27 '||);

            --Modifed on 13-Apr-2015
            IF c1_rec.attribute27 = 'ALL'         --OR c1_rec.segment3 = 'ALL'
            THEN
                lc_sample        := 'GENERIC';
                lc_attribute28   := 'GENERIC';
            /*    OPEN Get_template_id_c (lx_organization_id, lc_sample);

                ln_template_id := NULL;

                FETCH Get_template_id_c INTO ln_template_id;

                CLOSE Get_template_id_c; */
            END IF;

            --End Modifed on 13-`-2015

            --END IF;



            OPEN Get_template_id_c (lx_organization_id, lc_sample);

            ln_template_id               := NULL;

            FETCH Get_template_id_c INTO ln_template_id;

            CLOSE Get_template_id_c;



            IF ln_template_id IS NULL
            THEN
                l_record_error   := l_record_error + 1;
                l_error_msg      :=
                       l_error_msg
                    || '-'
                    || 'Error in Deriving Template Information : '
                    || SQLERRM;
            END IF;

            -- Org level validation----------

            -- fnd_file.put_line (fnd_file.LOG,                            'ln_template_id A  ' || ln_template_id);
            --fnd_file.put_line (fnd_file.LOG, 'lc_sample  ' || lc_sample);

            IF p_organization_code <> 'MST'
            THEN
                lc_dept_value              := NULL;
                lc_ret_brand_id            := NULL;
                lc_ret_brand_value         := NULL;
                get_brand_dept (p_item_id => c1_rec.inventory_item_id, x_dept => lc_dept_value, x_ret_brand_id => lc_ret_brand_id
                                , x_ret_brand_value => lc_ret_brand_value);


                IF (lc_dept_value IS NULL OR lc_ret_brand_id IS NULL OR lc_ret_brand_value IS NULL)
                THEN
                    l_error_msg   :=
                        l_error_msg || '-' || 'Could not derive Brand ';
                END IF;

                ln_buyer_id                := NULL;

                derive_buyer (p_brand => lc_ret_brand_value, p_dept => lc_dept_value, p_organization_id => lx_organization_id
                              , x_buyer_id => ln_buyer_id);



                IF ln_buyer_id IS NULL
                THEN
                    l_error_msg      :=
                        l_error_msg || '-' || 'Could not derive Buyer ';
                    l_record_error   := l_record_error + 1;
                END IF;

                lc_planner_code            := NULL;

                derive_planner_code (
                    p_brand             => lc_ret_brand_value,
                    p_organization_id   => c1_rec.organization_id,
                    x_planner_code      => lc_planner_code);



                IF lc_planner_code IS NULL
                THEN
                    l_error_msg      :=
                        l_error_msg || '-' || 'Could not derive Planner ';
                    l_record_error   := l_record_error + 1;
                END IF;


                ln_sales_account           := NULL;

                get_conc_code_combn (p_code_combn_id   => lx_sales_account,
                                     p_brand           => lc_ret_brand_id,
                                     x_new_ccid        => ln_sales_account);

                IF ln_sales_account IS NULL
                THEN
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Could not derive sales account ';
                    l_record_error   := l_record_error + 1;
                END IF;

                ln_cost_of_sales_account   := NULL;

                --COST_OF_SALES_ACCOUNT

                get_conc_code_combn (
                    p_code_combn_id   => lx_cogs_account,
                    p_brand           => lc_ret_brand_id,
                    x_new_ccid        => ln_cost_of_sales_account);

                IF ln_cost_of_sales_account IS NULL
                THEN
                    l_error_msg      :=
                           l_error_msg
                        || '-'
                        || 'Could not derive cost of sales account ';
                    l_record_error   := l_record_error + 1;
                END IF;
            END IF;

            --ATO Flag Update
            IF     p_organization_code = 'MST'
               AND c1_rec.item_number LIKE '%CUST%'
            THEN
                ln_template_id   := ln_temp_id;
            END IF;

            IF p_organization_code <> 'MC2'
            THEN
                lx_pp_lead_time   :=
                        (NVL (c1_rec.full_lead_time, 0) + NVL (c1_rec.POSTPROCESSING_LEAD_TIME, 0))
                      * 5
                      / 7
                    + NVL (ln_desc, 0);
            END IF;



            ----- Ogr level validations------

            IF l_record_error > 0
            THEN
                -- print_log (' -12-');
                --print_log ('l_record_error = ' || l_record_error);
                l_error_msg   := TRIM ('-' FROM l_error_msg);

                --print_log (l_error_msg);

                UPDATE xxd_item_conv_stg_t
                   --Update staging table with error messages and records status as 'E' for the error records.
                   SET record_status = 'E', error_message = SUBSTR (l_error_msg, 1, 2499), expense_account_no = l_expense_account_no,
                       expense_account = l_expense_account, organization_id = l_organization_id, encumbrance_account = l_encumbrance_account,
                       encumbrance_account_no = l_encumbrance_account_no, WEIGHT_UOM_CODE = lc_WEIGHT_UOM_CODE, VOLUME_UOM_CODE = lc_VOLUME_UOM_CODE,
                       DIMENSION_UOM_CODE = lc_DIMENSION_UOM_CODE, cost_of_sales_account = DECODE (p_organization_code, 'MST', l_cost_of_sales_account, ln_cost_of_sales_account), cost_of_sales_account_no = l_cost_of_sales_account_no,
                       sales_account = DECODE (p_organization_code, 'MST', l_sales_account, ln_sales_account), buyer_id = DECODE (p_organization_code, 'MST', buyer_id, ln_buyer_id), planner_code = DECODE (p_organization_code, 'MST', planner_code, lc_planner_code),
                       sales_account_no = l_sales_account_no, attribute28 = lc_attribute28, --lc_sample, Added on 05-JUN-2015
                                                                                            template_id = ln_template_id,
                       /* LIST_PRICE_PER_UNIT =
                           DECODE (p_organization_code,
                                   --'MST', LIST_PRICE_PER_UNIT,
                                   'US1', LIST_PRICE_PER_UNIT,
                                   'US2', LIST_PRICE_PER_UNIT,
                                   'US2', LIST_PRICE_PER_UNIT,
                                   ln_LIST_PRICE_PER_UNIT),*/
                       LIST_PRICE_PER_UNIT = ln_LIST_PRICE_PER_UNIT, --FULL_LEAD_TIME = DECODE (p_organization_code,                              'MST',FULL_LEAD_TIME,ln_FULL_LEAD_TIME),
                                                                     POSTPROCESSING_LEAD_TIME = lx_pp_lead_time
                 --DECODE (p_organization_code, 'MST', POSTPROCESSING_LEAD_TIME,    lx_pp_lead_time)
                 WHERE     record_id = c1_rec.record_id
                       AND batch_number = p_batch_no;
            ELSIF l_record_error = 0
            THEN
                --print_log (' -13-');
                --print_log ('l_record_error = ' || l_record_error);

                UPDATE xxd_item_conv_stg_t
                   --Update the error_message column as NULL while the record got validated in the second run.
                   SET error_message = l_error_msg, expense_account_no = l_expense_account_no, expense_account = l_expense_account,
                       organization_id = l_organization_id, encumbrance_account = l_encumbrance_account, encumbrance_account_no = l_encumbrance_account_no,
                       WEIGHT_UOM_CODE = lc_WEIGHT_UOM_CODE, VOLUME_UOM_CODE = lc_VOLUME_UOM_CODE, DIMENSION_UOM_CODE = lc_DIMENSION_UOM_CODE,
                       cost_of_sales_account = DECODE (p_organization_code, 'MST', l_cost_of_sales_account, ln_cost_of_sales_account), cost_of_sales_account_no = l_cost_of_sales_account_no, sales_account = DECODE (p_organization_code, 'MST', l_sales_account, ln_sales_account),
                       buyer_id = DECODE (p_organization_code, 'MST', buyer_id, ln_buyer_id), planner_code = DECODE (p_organization_code, 'MST', planner_code, lc_planner_code), sales_account_no = l_sales_account_no,
                       record_status = 'V', attribute28 = lc_attribute28, --lc_sample, Added on 05-JUN-2015
                                                                          template_id = ln_template_id,
                       --LIST_PRICE_PER_UNIT = DECODE (p_organization_code,                              'MST',LIST_PRICE_PER_UNIT,ln_LIST_PRICE_PER_UNIT),
                       LIST_PRICE_PER_UNIT = ln_LIST_PRICE_PER_UNIT, --FULL_LEAD_TIME = DECODE (p_organization_code,                              'MST',FULL_LEAD_TIME,ln_FULL_LEAD_TIME),
                                                                     --POSTPROCESSING_LEAD_TIME =  DECODE (p_organization_code, 'MST', POSTPROCESSING_LEAD_TIME,        lx_pp_lead_time)
                                                                     POSTPROCESSING_LEAD_TIME = lx_pp_lead_time
                 WHERE     record_id = c1_rec.record_id
                       AND batch_number = p_batch_no;
            --,ln_POSTPROCESSING_LEAD_TIME
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (' -14-');

            IF get_all_records%ISOPEN
            THEN
                CLOSE get_all_records;
            END IF;

            x_err_code   := 3;
            x_err_msg    :=
                   'OTHERS Exception in the Procedure validate_records_prc.  '
                || SUBSTR ('Error: ' || TO_CHAR (SQLCODE) || ':-' || SQLERRM,
                           1,
                           499);
            print_log (x_err_msg);
    END validate_records_prc;



    /*+=========================================================================================+
    | Procedure name                                                                            |
    |     submit_item_import                                                                    |
    |                                                                                           |
    | DESCRIPTION                                                                               |
    | Procedure submit_item_import to submit the standard item import program                          |
    +==========================================================================================*/
    PROCEDURE submit_item_import (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_organization_code IN VARCHAR)
    IS
        l_request_id        NUMBER;
        l_organization_id   NUMBER;

        CURSOR get_batch_number             --Cursor for Distinct Batch Number
                                IS
            SELECT DISTINCT organization_id, set_process_id
              FROM mtl_system_items_interface
             WHERE     process_flag = 1
                   AND organization_code = p_organization_code;

        l_flag              BOOLEAN := TRUE;
        l_phase_code        VARCHAR2 (30);



        ln_cntr             NUMBER := 0;
        lx_set_process_id   NUMBER := 0;

        TYPE xxd_org_set_t IS TABLE OF get_batch_number%ROWTYPE;

        gt_org_set_t        xxd_org_set_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id            request_table;
        lc_dev_phase        VARCHAR2 (200);
        lc_dev_status       VARCHAR2 (200);
        lb_wait             BOOLEAN;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_message          VARCHAR2 (4000);
    BEGIN
        ----l_organization_code:=p_organization_code;
        print_log ('inside submit import proc');

             /* UPDATE mtl_system_items_interface
                 SET inventory_item_status_code = 'Active'
               WHERE inventory_item_status_code = 'Excess';

              COMMIT;

              UPDATE mtl_system_items_interface
                 SET min_minmax_quantity = NULL
               WHERE 1 = 1 AND min_minmax_quantity IN (-1, 0);

              UPDATE mtl_system_items_interface
                 SET planner_code = NULL
               WHERE     1 = 1
                     AND organization_code LIKE 'T%'
                     AND planner_code IS NOT NULL;

              UPDATE mtl_system_items_interface
                 SET max_minmax_quantity = NULL
               WHERE 1 = 1 AND max_minmax_quantity = 0;

              COMMIT;
*/
        /*
                    SELECT organization_id
                      INTO l_organization_id
                      FROM mtl_parameters
                     WHERE organization_code = l_organization_code;


                    l_request_id :=
                       fnd_request.submit_request (application   => 'INV',
                                                   program       => 'INCOIN',
                                                   description   => NULL,
                                                   start_time    => SYSDATE,
                                                   sub_request   => FALSE,
                                                   argument1     => l_organization_id,
                                                   -- Organization id
                                                   argument2     => 2,  -- All organizations
                                                   argument3     => 1,     -- Validate Items
                                                   argument4     => 1,      -- Process Items
                                                   argument5     => 1, -- Delete Processed Rows
                                                   argument6     =>null,
                                                   -- Process Set (Null for All)
                                                   argument7     => 1, -- Create or Update Items
                                                   argument8     => 2   -- Gather Statistics
                                                                     );
                    COMMIT;
                  print_log ('request id1:' || l_request_id);
                    WHILE l_flag
                    LOOP
                       DBMS_LOCK.sleep (120);

                       SELECT phase_code
                         INTO l_phase_code
                         FROM fnd_conc_req_summary_v
                        WHERE request_id = l_request_id;
                       print_log ('phase code'||l_phase_code);
                       --and phase_code ='C'
                       IF l_phase_code = 'C'
                       THEN
                          l_flag := FALSE;
                       ELSE
                          l_flag := TRUE;
                       END IF;
                     END LOOP;
       print_log ('request id2:' || l_request_id);*/

        --Start

        --fnd_file.put_line (fnd_file.LOG, 'Test1');

        OPEN get_batch_number;


        FETCH get_batch_number BULK COLLECT INTO gt_org_set_t LIMIT 500;

        CLOSE get_batch_number;

        --fnd_file.put_line (fnd_file.LOG, 'Test2');

        FOR i IN gt_org_set_t.FIRST .. gt_org_set_t.LAST
        LOOP
            -- fnd_file.put_line (fnd_file.LOG, 'Test3');

            SELECT COUNT (*)
              INTO ln_cntr
              FROM mtl_system_items_interface
             WHERE     organization_id = gt_org_set_t (i).organization_id
                   AND set_process_id = gt_org_set_t (i).set_process_id;

            --fnd_file.put_line (fnd_file.LOG, 'Test4');

            IF ln_cntr > 0
            THEN
                BEGIN
                    l_request_id   :=
                        fnd_request.submit_request (application => 'INV', program => 'INCOIN', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => gt_org_set_t (i).organization_id, -- Organization id
                                                                                                                                                                                                                argument2 => 2, -- All organizations
                                                                                                                                                                                                                                argument3 => 1, -- Validate Items
                                                                                                                                                                                                                                                argument4 => 1, -- Process Items
                                                                                                                                                                                                                                                                argument5 => 2, -- Delete Processed Rows
                                                                                                                                                                                                                                                                                argument6 => gt_org_set_t (i).set_process_id, -- Process Set (Null for All)
                                                                                                                                                                                                                                                                                                                              argument7 => 1
                                                    , -- Create or Update Items
                                                      argument8 => 2 -- Gather Statistics
                                                                    );

                    IF l_request_id > 0
                    THEN
                        l_req_id (i)   := l_request_id;
                        COMMIT;
                    ELSE
                        ROLLBACK;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_retcode   := 2;
                        x_errbuf    := x_errbuf || SQLERRM;
                        print_log (
                               'Calling WAIT FOR REQUEST XXD_ITEM_LOAD_WRK error'
                            || SQLERRM);
                    WHEN OTHERS
                    THEN
                        x_retcode   := 2;
                        x_errbuf    := x_errbuf || SQLERRM;
                        print_log (
                               'Calling WAIT FOR REQUEST XXD_ITEM_LOAD_WRK error'
                            || SQLERRM);
                END;
            END IF;
        END LOOP;

        --fnd_file.put_line (fnd_file.LOG, 'Test5');

        gt_org_set_t.delete;

        --fnd_file.put_line (fnd_file.LOG, 'Test6');

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
                                INTERVAL     => 1,
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
    --End

    /*  FOR l_rec IN get_batch_number
      LOOP
         l_request_id :=
            fnd_request.submit_request (
               application   => 'INV',
               program       => 'INCOIN',
               description   => NULL,
               start_time    => SYSDATE,
               sub_request   => FALSE,
               argument1     => l_rec.organization_id,      -- Organization id
               argument2     => 2,                        -- All organizations
               argument3     => 1,                           -- Validate Items
               argument4     => 1,                            -- Process Items
               argument5     => 2,                    -- Delete Processed Rows
               argument6     => l_rec.set_process_id,
               -- Process Set (Null for All)
               argument7     => 1,                   -- Create or Update Items
               argument8     => 2                         -- Gather Statistics
                                 );
         print_log ('Organization ID:' || l_rec.organization_id);
         print_log ('l_rec.set_process_id:' || l_rec.set_process_id);
         print_log ('l_request_id:' || l_request_id);
         COMMIT;
      END LOOP; */
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (SUBSTR (SQLERRM, 1, 500));
    END submit_item_import;

    PROCEDURE PROCESS_ITEM_ORG_ASSIGNMENT (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_debug IN VARCHAR2)
    AS
        CURSOR get_item_attr_cur (p_last_run_date DATE)
        IS
            (SELECT /*+ FIRST_ROWS(10) */
                    msi.inventory_item_id, msi.segment1
               FROM mtl_system_items_b msi, mtl_parameters mp
              WHERE     msi.organization_id = mp.organization_id
                    AND ORGANIZATION_CODE = 'MST'
                    AND msi.creation_date LIKE (SYSDATE - 1) --       AND msi.creation_date >=                         TO_DATE (p_last_run_date, 'DD-MON-RRRR HH24:MI:SS')
                                                            );

        l_api_version                 NUMBER := 1.0;
        l_init_msg_list               VARCHAR2 (2) := fnd_api.g_true;
        l_commit                      VARCHAR2 (2) := fnd_api.g_false;
        l_item_org_assignment_tbl     ego_item_pub.item_org_assignment_tbl_type;
        x_message_list                error_handler.error_tbl_type;
        x_return_status               VARCHAR2 (2);
        x_msg_count                   NUMBER := 0;
        l_user_id                     NUMBER := -1;
        l_resp_id                     NUMBER := -1;
        l_application_id              NUMBER := -1;
        l_rowcnt                      NUMBER := 0;
        l_user_name                   VARCHAR2 (30) := 'CONV';
        l_resp_name                   VARCHAR2 (30) := 'Inventory';

        TYPE inv_item_attr_tab IS TABLE OF get_item_attr_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_inv_item_attr_t           inv_item_attr_tab;
        l_profile_date                DATE;


        l_item_tbl_typ                ego_item_pub.item_tbl_type;
        x_item_tbl_typ                ego_item_pub.item_tbl_type;
        lc_err_message_text           VARCHAR2 (4000);

        CURSOR get_account_c (p_organization_id IN NUMBER)
        IS
            SELECT SALES_ACCOUNT, COST_OF_SALES_ACCOUNT, organization_id
              FROM mtl_parameters mp
             WHERE organization_id = p_organization_id;

        lcu_get_account_c             get_account_c%ROWTYPE;

        --BT Changes
        CURSOR get_org_data_c (p_inventory_item_id   IN NUMBER,
                               p_organization_id     IN NUMBER)
        IS
            SELECT LIST_PRICE_PER_UNIT, FULL_LEAD_TIME
              FROM XXD_ITEM_CONV_STG_T
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = p_organization_id;

        ln_LIST_PRICE_PER_UNIT        NUMBER;
        ln_POSTPROCESSING_LEAD_TIME   NUMBER;



        CURSOR get_code_combnation_id (p_code_combination IN VARCHAR2)
        IS
            SELECT code_combination_id
              FROM gl_code_combinations_kfv
             WHERE     CONCATENATED_SEGMENTS = p_code_combination
                   AND enabled_flag = 'Y';

        lc_ret_brand_value            VARCHAR2 (20);
        lc_brand_value                VARCHAR2 (20);

        CURSOR get_dept_c (p_item_id NUMBER)
        IS
            SELECT segment3
              FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                   org_organization_definitions ood
             WHERE     mic.organization_id = ood.organization_id
                   AND organization_code = 'MST'
                   AND inventory_item_id = p_item_id
                   AND mcs.category_set_name = 'Inventory'
                   AND mc.category_id = mic.category_id;

        lc_dept                       VARCHAR2 (100);
        lc_region                     VARCHAR2 (100);
        lc_buyer                      VARCHAR2 (100);

        TYPE get_item IS REF CURSOR;

        get_item_attr                 get_item;

        lc_error_message              VARCHAR2 (4000);
        lc_error_flag                 VARCHAR2 (1);


        ln_COST_OF_SALES_ACCOUNT_ID   NUMBER;
        ln_SALES_ACCOUNT_ID           NUMBER;
        lc_COST_OF_SALES_ACCOUNT      VARCHAR2 (500);
        lc_SALES_ACCOUNT              VARCHAR2 (500);
        lc_i_COST_OF_SALES_ACCOUNT    VARCHAR2 (500);
        lc_i_SALES_ACCOUNT            VARCHAR2 (500);
        lc_l_err_msg                  VARCHAR2 (100);
        ln_coa_id                     NUMBER;
        ln_organization_id            NUMBER;



        CURSOR Get_buyer_id_c (p_brand    VARCHAR2,
                               p_dept     VARCHAR2,
                               p_org_id   NUMBER)
        IS
            SELECT agent_id                                        --, flv.tag
              --INTO lc_region, lc_buyer, lc_dept1
              FROM fnd_lookup_values flv, per_all_people_f ppf, po_agents pa,
                   mtl_parameters mp
             WHERE     flv.attribute1 = p_brand
                   AND lookup_type = 'DO_BUYER_CODE'
                   --AND ( (flv.attribute2 = p_dept) OR flv.attribute2 IS NULL)
                   AND ((flv.attribute2 = p_dept) OR flv.attribute2 = 'ALL')
                   --DECODE (flv.attribute2, 'ALL', 'ALL', p_dept)
                   AND ppf.full_name = DESCRIPTION
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   ppf.effective_start_date)
                                           AND TRUNC (
                                                   NVL (
                                                       ppf.effective_end_date,
                                                       SYSDATE))
                   AND ((NVL (mp.attribute1, flv.tag) = flv.tag) OR NVL (mp.attribute1, 'XX') = NVL (flv.tag, 'XX') OR NVL (flv.tag, mp.attribute1) = mp.attribute1)
                   AND pa.agent_id = ppf.person_id
                   AND mp.organization_id = p_org_id;

        ln_buyer_id                   NUMBER;



        CURSOR get_palnner_code_c (p_brand             VARCHAR2,
                                   p_organization_id   NUMBER)
        IS
            SELECT DESCRIPTION, meaning
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.tag = p_brand
                   AND lookup_type = 'DO_PLANNER_CODE'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND mp.organization_id = p_organization_id
                   AND DESCRIPTION = mp.attribute1;

        lcu_Get_palnner_code_c        Get_palnner_code_c%ROWTYPE;

        lc_planner_code               VARCHAR2 (100);



        CURSOR get_template_id_c (p_organization_id NUMBER)
        IS
            SELECT template_id
              FROM fnd_lookup_values flv, mtl_item_templates mit, org_organization_definitions ood
             WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND flv.description = mit.template_name
                   AND ood.organization_code = flv.attribute10
                   AND ood.organization_id = p_organization_id;

        ln_template_id                NUMBER;


        CURSOR get_ppt_time_c (p_org_id NUMBER)
        IS
            SELECT Description
              FROM fnd_lookup_values flv, org_organization_definitions ood
             WHERE     lookup_type = 'DO_POST_PROCESSING'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.Language = USERENV ('LANG')
                   AND ood.organization_code = flv.lookup_code
                   AND organization_id = p_org_id;

        lc_pp_lead_time               VARCHAR (100);


        CURSOR get_org_details (p_item_id NUMBER)
        IS
            SELECT mp.organization_id, mp.organization_code, msi.inventory_item_id
              FROM mtl_parameters mp, mtl_system_items_b msi
             WHERE     mp.organization_code IN ('MST', 'US1', 'US2',
                                                'US3', 'EUC', 'CH3',
                                                'CH4', 'HK1', 'JP5',
                                                'JPC', 'MC1', 'MC2',
                                                'EUZ', 'EUB', 'CNC',
                                                'HKC', 'FLG', 'APB',
                                                'XXC', 'USB', 'USC',
                                                'USX', 'USZ', 'EU3',
                                                'EU4')
                   AND msi.organization_id = mp.organization_id
                   AND msi.inventory_item_id = p_item_id; --AND msi.organization_id = 123


        lcu_get_org_details           get_org_details%ROWTYPE;

        ln_break_segs                 NUMBER;
        lc_seg_out                    fnd_flex_ext.segmentarray;
        lc_concat_seg                 VARCHAR2 (1000);


        FUNCTION item_notin_org (p_item_id IN NUMBER, p_org_id IN NUMBER)
            RETURN BOOLEAN
        IS
            ln_count   NUMBER;
        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM mtl_system_items_b
             WHERE     inventory_item_id = p_item_id
                   AND organization_id = p_org_id;

            IF ln_count = 0
            THEN
                RETURN TRUE;
            END IF;

            RETURN FALSE;
        END item_notin_org;



        PROCEDURE upd_profile_value_p
        AS
            l_success   BOOLEAN;
        BEGIN
            l_success   :=
                fnd_profile.SAVE (
                    x_name                 => 'XXD_INV_ORG_ASSIGNMENT_RUN_DATE',
                    x_value                => TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
                    x_level_name           => 'SITE',
                    x_level_value          => NULL,
                    x_level_value_app_id   => NULL);

            IF l_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Profile Updated successfully at site Level');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Profile Update Failed at site Level. Error:');
            END IF;
        --
        -- Commit is needed because this function will not commit
        --
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'upd_profile_value_p :');
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'upd_profile_value_p :');
        END upd_profile_value_p;



        FUNCTION get_brand (p_item_id IN NUMBER)
            RETURN VARCHAR2
        IS
            CURSOR get_brand_c (p_item_id NUMBER)
            IS
                SELECT segment1
                  FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                       org_organization_definitions ood
                 WHERE     mic.organization_id = ood.organization_id
                       AND organization_code = 'MST'
                       AND inventory_item_id = p_item_id
                       AND mic.category_set_id = mcs.category_set_id
                       AND mcs.category_set_name = 'Inventory'
                       AND mc.category_id = mic.category_id;

            lc_brand         VARCHAR2 (100);
            lc_brand_value   VARCHAR2 (15);
        BEGIN
            OPEN get_brand_c (p_item_id);

            lc_brand   := NULL;

            FETCH get_brand_c INTO lc_brand;

            CLOSE get_brand_c;



            RETURN lc_brand;
        END get_brand;


        FUNCTION get_conc_code_combn (p_code_combn_id IN VARCHAR2)
            RETURN VARCHAR2
        IS
            CURSOR get_conc_code_combn_c IS
                SELECT CONCATENATED_SEGMENTS
                  FROM gl_code_combinations_kfv
                 WHERE code_combination_id = p_code_combn_id;

            lc_conc_code_combn   VARCHAR2 (100);
        BEGIN
            OPEN get_conc_code_combn_c;

            FETCH get_conc_code_combn_c INTO lc_conc_code_combn;

            CLOSE get_conc_code_combn_c;

            RETURN lc_conc_code_combn;
        END get_conc_code_combn;
    BEGIN
        BEGIN
            -- Get the user_id
            SELECT user_id
              INTO l_user_id
              FROM fnd_user
             WHERE user_name = l_user_name;

            -- Get the application_id and responsibility_id
            SELECT application_id, responsibility_id
              INTO l_application_id, l_resp_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = l_resp_name;

            SELECT CHART_OF_ACCOUNTS_ID
              INTO ln_coa_id
              FROM gl_sets_of_books
             WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                prt_log (p_debug,
                         'Error while deriving user_id,resp_id,coa ');
        END;



        fnd_global.apps_initialize (l_user_id, l_resp_id, l_application_id);
        -- MGRPLM / Development Manager / EGO
        fnd_file.put_line (
            fnd_file.LOG,
               'Initialized applications context: '
            || l_user_id
            || ' '
            || l_resp_id
            || ' '
            || l_application_id);

        -- Get the item that needs to be assigned


        -- Item name
        OPEN get_item_attr_cur (p_last_run_date => l_profile_date);

        LOOP
            l_rowcnt   := 0;
            gtt_inv_item_attr_t.delete;
            l_item_org_assignment_tbl.delete;

            FETCH get_item_attr_cur
                BULK COLLECT INTO gtt_inv_item_attr_t
                LIMIT 100;



            FOR i IN 1 .. gtt_inv_item_attr_t.COUNT
            LOOP
                -- Get the organization to which the item needs to be assigned

                lc_error_flag      := 'N';
                lc_error_message   := NULL;

                prt_log (
                    p_debug,
                       'Processing for item  '
                    || gtt_inv_item_attr_t (i).segment1);


                lc_brand_value     :=
                    get_brand (gtt_inv_item_attr_t (i).inventory_item_id);

                prt_log (p_debug,
                         'brand of the item    : ' || lc_brand_value);



                BEGIN
                    SELECT ffv.FLEX_VALUE
                      INTO lc_ret_brand_value
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                     WHERE     flex_value_set_name = 'DO_GL_BRAND'
                           AND ffvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
                           AND UPPER (ffv.DESCRIPTION) =
                               UPPER (lc_brand_value);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_error_flag   := 'Y';
                        lc_error_message   :=
                            'Failed to derive GL brand for item ';
                END;



                OPEN get_dept_c (gtt_inv_item_attr_t (i).inventory_item_id);

                lc_dept            := NULL;

                FETCH get_dept_c INTO lc_dept;

                IF lc_dept IS NULL
                THEN
                    lc_error_flag   := 'Y';
                    lc_error_message   :=
                           lc_error_message
                        || ','
                        || 'Failed to derive lc_error_message for item ';
                END IF;

                CLOSE get_dept_c;

                prt_log (p_debug, 'Department of the item   ' || lc_dept);

                IF lc_error_flag = 'Y'
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'INV',    --Oracle module short name
                        p_org_id       => gn_org_id,
                        p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                        p_error_msg    => SUBSTR (SQLERRM, 1, 2000), --SQLERRM
                        p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                        p_created_by   => gn_user_id,                --USER_ID
                        p_request_id   => gn_request_id, -- concurrent request ID
                        p_more_info1   => 'Deriving brand  ',
                        p_more_info2   =>
                               'Item id  '
                            || gtt_inv_item_attr_t (i).Inventory_item_id, --additional information for troubleshooting,
                        p_more_info3   => lc_error_message);
                END IF;



                FOR orgs IN (SELECT mp.organization_id, mp.organization_code
                               FROM mtl_parameters mp
                              WHERE mp.organization_code IN ('MST', 'US1', 'US2',
                                                             'US3', 'EUC', 'CH3',
                                                             'CH4', 'HK1', 'JP5',
                                                             'JPC', 'MC1', 'MC2',
                                                             'EUZ', 'EUB', 'CNC',
                                                             'HKC', 'FLG', 'APB',
                                                             'XXC', 'USB', 'USC',
                                                             'USX', 'USZ', 'EU3',
                                                             'EU4'))
                LOOP
                    lc_error_flag      := 'N';
                    lc_error_message   := NULL;

                    IF item_notin_org (
                           p_item_id   =>
                               gtt_inv_item_attr_t (i).inventory_item_id,
                           p_org_id   => orgs.organization_id)
                    THEN
                        l_rowcnt                      := l_rowcnt + 1;
                        l_item_org_assignment_tbl (l_rowcnt).inventory_item_id   :=
                            gtt_inv_item_attr_t (i).inventory_item_id;
                        l_item_org_assignment_tbl (l_rowcnt).organization_id   :=
                            orgs.organization_id;
                        l_item_org_assignment_tbl (l_rowcnt).organization_code   :=
                            orgs.organization_code;


                        prt_log (
                            p_debug,
                               'Processing data for Item  '
                            || gtt_inv_item_attr_t (i).segment1
                            || 'and organization '
                            || lcu_get_org_details.organization_code);


                        lcu_get_account_c             := NULL;

                        OPEN get_account_c (orgs.organization_id);

                        --LOOP
                        FETCH get_account_c INTO lcu_get_account_c;

                        CLOSE get_account_c;

                        prt_log (
                            p_debug,
                               'Sales account id for the org '
                            || lcu_get_account_c.SALES_ACCOUNT);
                        prt_log (
                            p_debug,
                               'Cost of sales account id for the org '
                            || lcu_get_account_c.COST_OF_SALES_ACCOUNT);



                        IF (lcu_get_account_c.sales_account IS NULL OR lcu_get_account_c.cost_of_sales_account IS NULL)
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                'Failed to derive sales_account or  cost_of_sales_account for organization_code ';
                        END IF;

                        prt_log (p_debug,
                                 'Deriving buyer id ----------------------');


                        OPEN Get_buyer_id_c (lc_brand_value,
                                             lc_dept,
                                             orgs.organization_id);

                        ln_buyer_id                   := NULL;

                        FETCH Get_buyer_id_c INTO ln_buyer_id;

                        CLOSE Get_buyer_id_c;

                        IF ln_buyer_id IS NULL
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || 'Failed to derive buyer for organization_code ';
                        END IF;


                        prt_log (p_debug, 'Buyer id  ' || ln_buyer_id);


                        OPEN get_template_id_c (orgs.organization_id);

                        ln_template_id                := NULL;

                        FETCH get_template_id_c INTO ln_template_id;

                        CLOSE get_template_id_c;

                        IF ln_template_id IS NULL
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || 'Failed to derive Template for organization_code ';
                        END IF;


                        --prt_log (p_debug, 'Template id  ' || ln_template_id);


                        OPEN Get_palnner_code_c (lc_brand_value,
                                                 orgs.organization_id);

                        lcu_Get_palnner_code_c        := NULL;

                        FETCH Get_palnner_code_c INTO lcu_Get_palnner_code_c;

                        CLOSE Get_palnner_code_c;

                        IF lcu_Get_palnner_code_c.meaning IS NULL
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || 'Failed to derive planner code for organization_code ';
                        END IF;

                        prt_log (
                            p_debug,
                            'Planner code   ' || lcu_Get_palnner_code_c.meaning);


                        OPEN get_ppt_time_c (orgs.organization_id);

                        lc_pp_lead_time               := NULL;

                        FETCH get_ppt_time_c INTO lc_pp_lead_time;

                        CLOSE get_ppt_time_c;

                        prt_log (p_debug,
                                 'processing time ' || lc_pp_lead_time);



                        IF lc_pp_lead_time IS NULL
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || 'Failed to derive pp lead time ';
                        END IF;

                        lc_COST_OF_SALES_ACCOUNT      := NULL;

                        lc_COST_OF_SALES_ACCOUNT      :=
                            get_conc_code_combn (
                                lcu_get_account_c.COST_OF_SALES_ACCOUNT);

                        lc_SALES_ACCOUNT              := NULL;

                        lc_SALES_ACCOUNT              :=
                            get_conc_code_combn (
                                lcu_get_account_c.SALES_ACCOUNT);

                        prt_log (
                            p_debug,
                               'Cost of sales account for the org    '
                            || lc_COST_OF_SALES_ACCOUNT);

                        prt_log (
                            p_debug,
                               'Sales account for the org    '
                            || lc_SALES_ACCOUNT);


                        ln_break_segs                 := NULL;
                        ln_break_segs                 :=
                            fnd_flex_ext.breakup_segments (
                                lc_COST_OF_SALES_ACCOUNT,
                                '.',
                                lc_seg_out);
                        lc_concat_seg                 := NULL;

                        FOR i IN 1 .. ln_break_segs
                        LOOP
                            IF lc_seg_out (i) IS NULL
                            THEN
                                EXIT;
                            ELSIF i = 1
                            THEN
                                lc_concat_seg   := lc_seg_out (i);
                            ELSIF i = 2
                            THEN
                                lc_concat_seg   :=
                                       lc_concat_seg
                                    || '.'
                                    || lc_ret_brand_value;
                            ELSIF i > 2
                            THEN
                                lc_concat_seg   :=
                                    lc_concat_seg || '.' || lc_seg_out (i);
                            END IF;
                        END LOOP;



                        lc_i_COST_OF_SALES_ACCOUNT    := lc_concat_seg;


                        prt_log (
                            p_debug,
                               'Derived Cost of sales account     '
                            || lc_i_COST_OF_SALES_ACCOUNT);

                        --test111 ('Test6 ' || lc_i_COST_OF_SALES_ACCOUNT);

                        lc_i_SALES_ACCOUNT            := NULL;



                        ln_break_segs                 := NULL;
                        ln_break_segs                 :=
                            fnd_flex_ext.breakup_segments (
                                lc_COST_OF_SALES_ACCOUNT,
                                '.',
                                lc_seg_out);
                        lc_concat_seg                 := NULL;

                        FOR i IN 1 .. ln_break_segs
                        LOOP
                            IF lc_seg_out (i) IS NULL
                            THEN
                                EXIT;
                            ELSIF i = 1
                            THEN
                                lc_concat_seg   := lc_seg_out (i);
                            ELSIF i = 2
                            THEN
                                lc_concat_seg   :=
                                       lc_concat_seg
                                    || '.'
                                    || lc_ret_brand_value;
                            ELSIF i > 2
                            THEN
                                lc_concat_seg   :=
                                    lc_concat_seg || '.' || lc_seg_out (i);
                            END IF;
                        END LOOP;



                        lc_i_SALES_ACCOUNT            := lc_concat_seg;


                        prt_log (
                            p_debug,
                               'Derived Cost of sales account     '
                            || lc_i_COST_OF_SALES_ACCOUNT);



                        prt_log (
                            p_debug,
                               'Derived Sales account     '
                            || lc_i_SALES_ACCOUNT);
                        prt_log (
                            p_debug,
                            'Deriving  Code combination id for the cost of sales account ');



                        BEGIN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Calling Fnd_Flex_Ext.get_ccid to derive ccid ');
                            ln_COST_OF_SALES_ACCOUNT_ID   :=
                                Fnd_Flex_Ext.get_ccid (
                                    'SQLGL',
                                    'GL#',
                                    ln_coa_id,                         --50388
                                    TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                    lc_i_COST_OF_SALES_ACCOUNT);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                prt_log (
                                    p_debug,
                                    'Could not derive ccid  by calling Fnd_Flex_Ext.get_ccid for cost of sales account  ');
                                ln_COST_OF_SALES_ACCOUNT_ID   := NULL;
                                lc_l_err_msg                  :=
                                    'Fnd_Flex_Ext.get_ccid failed to derive ccid';
                                lc_error_flag                 := 'Y';
                                lc_error_message              :=
                                       lc_error_message
                                    || ','
                                    || 'Failed to derive cost of sales account  ';
                        END;


                        prt_log (
                            p_debug,
                            'Deriving  Code combination id for the  sales account ');



                        BEGIN
                            ln_SALES_ACCOUNT_ID   :=
                                Fnd_Flex_Ext.get_ccid (
                                    'SQLGL',
                                    'GL#',
                                    ln_coa_id,                         --50388
                                    TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                    lc_i_SALES_ACCOUNT);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                prt_log (
                                    p_debug,
                                    'Could not derive ccid  by calling Fnd_Flex_Ext.get_ccid for cost of sales account  ');



                                ln_SALES_ACCOUNT_ID   := NULL;
                                lc_l_err_msg          :=
                                    'Fnd_Flex_Ext.get_ccid failed to derive ccid';

                                lc_error_flag         := 'Y';
                                lc_error_message      :=
                                       lc_error_message
                                    || ','
                                    || 'Failed to derive sales account lead time ';
                        END;

                        --END IF;

                        prt_log (
                            p_debug,
                            'Deriving List price and post processing time ');



                        OPEN get_org_data_c (
                            gtt_inv_item_attr_t (i).inventory_item_id,
                            orgs.organization_id);

                        ln_LIST_PRICE_PER_UNIT        := NULL;

                        ln_POSTPROCESSING_LEAD_TIME   := NULL;

                        FETCH get_org_data_c INTO ln_LIST_PRICE_PER_UNIT, ln_POSTPROCESSING_LEAD_TIME;

                        CLOSE get_org_data_c;

                        prt_log (p_debug,
                                 '  List price ' || ln_LIST_PRICE_PER_UNIT);
                        prt_log (
                            p_debug,
                               'Post processing lead time  '
                            || ln_POSTPROCESSING_LEAD_TIME);


                        IF (ln_LIST_PRICE_PER_UNIT IS NULL OR ln_POSTPROCESSING_LEAD_TIME IS NULL)
                        THEN
                            lc_error_flag   := 'Y';
                            lc_error_message   :=
                                   lc_error_message
                                || ','
                                || 'Failed to derive pp lead time ';
                        END IF;


                        IF lc_error_flag = 'Y'
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'INV', --Oracle module short name
                                p_org_id       => gn_org_id,
                                p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                p_error_msg    => SUBSTR (SQLERRM, 1, 2000), --SQLERRM
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                p_created_by   => gn_user_id,        --USER_ID
                                p_request_id   => gn_request_id, -- concurrent request ID
                                p_more_info1   => 'Organization id ' || orgs.organization_id,
                                p_more_info2   =>
                                       'Item id  '
                                    || gtt_inv_item_attr_t (i).Inventory_item_id, --additional information for troubleshooting,
                                p_more_info3   => lc_error_message);
                        END IF;


                        prt_log (
                            p_debug,
                            'Assigning values to the table type l_item_tbl_typ  --------- ');



                        --fnd_global.apps_initialize (0, 20634, 401);

                        l_item_tbl_typ (l_rowcnt).transaction_type   :=
                            'UPDATE';
                        l_item_tbl_typ (l_rowcnt).inventory_item_id   :=
                            gtt_inv_item_attr_t (i).inventory_item_id;
                        l_item_tbl_typ (l_rowcnt).organization_id   :=
                            orgs.organization_id;

                        IF     ln_COST_OF_SALES_ACCOUNT_ID IS NOT NULL
                           AND ln_COST_OF_SALES_ACCOUNT_ID <> 0
                        THEN
                            l_item_tbl_typ (l_rowcnt).COST_OF_SALES_ACCOUNT   :=
                                ln_COST_OF_SALES_ACCOUNT_ID;
                        END IF;

                        IF     ln_COST_OF_SALES_ACCOUNT_ID IS NOT NULL
                           AND ln_SALES_ACCOUNT_ID <> 0
                        THEN
                            l_item_tbl_typ (l_rowcnt).SALES_ACCOUNT   :=
                                ln_SALES_ACCOUNT_ID;
                        END IF;


                        IF ln_template_id IS NOT NULL
                        THEN
                            l_item_tbl_typ (l_rowcnt).template_id   :=
                                ln_template_id;
                        END IF;

                        IF ln_LIST_PRICE_PER_UNIT IS NOT NULL
                        THEN
                            l_item_tbl_typ (l_rowcnt).LIST_PRICE_PER_UNIT   :=
                                ln_LIST_PRICE_PER_UNIT;
                        END IF;

                        IF lc_pp_lead_time IS NOT NULL
                        THEN
                            l_item_tbl_typ (l_rowcnt).POSTPROCESSING_LEAD_TIME   :=
                                lc_pp_lead_time;
                        END IF;

                        IF ln_buyer_id IS NOT NULL
                        THEN
                            l_item_tbl_typ (l_rowcnt).BUYER_ID   :=
                                ln_buyer_id;
                        END IF;

                        IF lcu_Get_palnner_code_c.meaning IS NOT NULL
                        THEN
                            l_item_tbl_typ (l_rowcnt).planner_code   :=
                                UPPER (lcu_Get_palnner_code_c.meaning);
                        END IF;
                    END IF;
                END LOOP;
            --END IF;
            END LOOP;


            IF l_item_org_assignment_tbl.COUNT > 0
            THEN
                -- call API to assign Items
                fnd_file.put_line (
                    fnd_file.LOG,
                    '===========================================');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Calling EGO_ITEM_PUB.Process_Item_Org_Assignment API');
                ego_item_pub.process_item_org_assignments (
                    p_api_version               => l_api_version,
                    p_init_msg_list             => l_init_msg_list,
                    p_commit                    => l_commit,
                    p_item_org_assignment_tbl   => l_item_org_assignment_tbl,
                    x_return_status             => x_return_status,
                    x_msg_count                 => x_msg_count);
                fnd_file.put_line (
                    fnd_file.LOG,
                    '=========================================');

                prt_log (p_debug, 'Return Status: ' || x_return_status);


                IF (x_return_status <> fnd_api.g_ret_sts_success)
                THEN
                    fnd_file.put_line (fnd_file.LOG, 'Error Messages :');
                    error_handler.get_message_list (
                        x_message_list => x_message_list);
                    lc_err_message_text   := NULL;

                    FOR i IN 1 .. x_message_list.COUNT
                    LOOP
                        fnd_file.put_line (fnd_file.LOG,
                                           x_message_list (i).MESSAGE_TEXT);
                        lc_err_message_text   :=
                            SUBSTR (
                                   lc_err_message_text
                                || ','
                                || x_message_list (i).MESSAGE_TEXT,
                                1,
                                4000);
                    END LOOP;

                    xxd_common_utils.record_error (
                        p_module       => 'INV',    --Oracle module short name
                        p_org_id       => gn_org_id,
                        p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                        p_error_msg    => SUBSTR (SQLERRM, 1, 2000), --SQLERRM
                        p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                        p_created_by   => gn_user_id,                --USER_ID
                        p_request_id   => gn_request_id, -- concurrent request ID
                        p_more_info1   => 'Item id  ');
                END IF;



                fnd_file.put_line (
                    fnd_file.LOG,
                    '=============================================================================');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Calling API  ego_item_pub.process_items  ');



                ego_item_pub.process_items (
                    p_api_version      => 1.0,
                    p_init_msg_list    => fnd_api.g_false,
                    p_commit           => fnd_api.g_true,
                    p_item_tbl         => l_item_tbl_typ,
                    x_item_tbl         => x_item_tbl_typ,
                    p_role_grant_tbl   => ego_item_pub.g_miss_role_grant_tbl,
                    x_return_status    => x_return_status,
                    x_msg_count        => x_msg_count);

                fnd_file.put_line (fnd_file.LOG,
                                   'x_return_status : ' || x_return_status);
                error_handler.get_message_list (x_message_list);
                lc_err_message_text   := NULL;

                IF x_return_status <> 'S'
                THEN
                    FOR i IN 1 .. x_message_list.COUNT
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error message from the API ego_item_pub.process_items');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '===================================================================');

                        fnd_file.put_line (fnd_file.LOG,
                                           x_message_list (i).MESSAGE_TEXT);
                        lc_err_message_text   :=
                            SUBSTR (
                                   lc_err_message_text
                                || ','
                                || x_message_list (i).MESSAGE_TEXT,
                                1,
                                4000);
                    END LOOP;
                END IF;

                IF lc_err_message_text IS NOT NULL
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'INV',    --Oracle module short name
                        p_org_id       => gn_org_id,
                        p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                        p_error_msg    => SUBSTR (SQLERRM, 1, 2000), --SQLERRM
                        p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                        p_created_by   => gn_user_id,                --USER_ID
                        p_request_id   => gn_request_id, -- concurrent request ID
                        p_more_info1   =>
                               'Error  '
                            || SUBSTR (lc_err_message_text, 1, 2000));
                END IF;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               '=========================================');
            fnd_file.put_line (
                fnd_file.LOG,
                '                                                                                                       ');
            fnd_file.put_line (
                fnd_file.LOG,
                '                                                                                                       ');
            COMMIT;



            gtt_inv_item_attr_t.delete;
            l_item_tbl_typ.delete;
            x_item_tbl_typ.delete;                                -- Item name
            EXIT WHEN get_item_attr_cur%NOTFOUND;
        --      dbms_output.put_line('Trying to assign Item: '|| gtt_inv_item_attr_t(i).Inventory_Item_Id || ' to organization '||);
        END LOOP;                                     -- p_organization_code ;

        CLOSE get_item_attr_cur;

        upd_profile_value_p;
    --UPDATE_SALES_COGS_ACCOUNT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception Occured :');
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ':' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG,
                               '========================================');
    END PROCESS_ITEM_ORG_ASSIGNMENT;
END XXD_ITEM_CONV_PKG;
/
