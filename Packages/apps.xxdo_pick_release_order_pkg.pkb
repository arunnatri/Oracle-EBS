--
-- XXDO_PICK_RELEASE_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PICK_RELEASE_ORDER_PKG"
AS
    /******************************************************************************************************
       * Program Name : XXDO_PICK_RELEASE_ORDER_PKG
       * Language     : PL/SQL
       * Description  :
       *
       * History      :
       *
       * WHO                  Version                  Desc                                      WHEN
       * --------------       -------    ---------------------------------------             ---------------
       *                       1.0       Initial Version
       * Tejaswi Gangumalla    1.1       Modified parameters for                              08-Aug-2020
                                         program "Pick Release - Deckers" -CCR0008630
       ******************************************************************************************************/
    PROCEDURE xxdo_pick_release_for_order (
        p_out_chr_ret_message         OUT NOCOPY VARCHAR2,
        p_out_num_ret_status          OUT NOCOPY NUMBER,
        p_req_id_str                  OUT NOCOPY VARCHAR2,
        p_user_id                  IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_appl_id             IN            NUMBER,
        p_order                                  NUMBER,
        p_min_line_pick_pct                      NUMBER,
        p_min_unit_pick_pct                      NUMBER,
        p_min_line_cnt_pick_pct                  NUMBER,
        p_min_line_unit_pick_pct                 NUMBER)
    AS
        l_out_chr_ret_message      VARCHAR2 (100) := p_out_chr_ret_message;
        l_out_num_ret_status       NUMBER := p_out_num_ret_status;
        l_order                    NUMBER := p_order;
        l_min_line_pick_pct        NUMBER := p_min_line_pick_pct;
        l_min_unit_pick_pct        NUMBER := p_min_unit_pick_pct;
        l_min_line_cnt_pick_pct    NUMBER := p_min_line_cnt_pick_pct;
        l_min_line_unit_pick_pct   NUMBER := p_min_line_unit_pick_pct;
        l_request_id               NUMBER := 0;
        v_concat                   VARCHAR2 (1000);
        l_option_return            BOOLEAN;
        l_application_short_name   VARCHAR2 (10) := 'XXDO';

        --Cursor to fetch distinct warehouses for the order
        CURSOR c_get_warehouses IS
              SELECT DISTINCT a.ship_from_org_id, b.order_number, ood.organization_name
                FROM oe_order_lines_all a, oe_order_headers_all b, hr_operating_units hou,
                     org_organization_definitions ood
               WHERE     a.org_id = b.org_id
                     AND a.header_id = b.header_id
                     AND hou.organization_id = ood.operating_unit
                     AND ood.organization_id = a.ship_from_org_id
                     AND b.order_number = l_order
            ORDER BY ood.organization_name;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Start XXDO_PICK_RELEASE_FOR_ORDER procedures');

        FOR rec_cursor IN c_get_warehouses
        LOOP
            apps.fnd_global.apps_initialize (user_id        => p_user_id,
                                             resp_id        => p_resp_id,
                                             resp_appl_id   => p_resp_appl_id);
            -- adding the template to generate excel output
            l_option_return   :=
                fnd_request.add_layout (
                    template_appl_name   => l_application_short_name,
                    template_code        => 'DO_PICK_RELEASE',
                    template_language    => 'En',
                    template_territory   => 'US',
                    output_format        => 'EXCEL');
            --FND_FILE.PUT_LINE (FND_FILE.LOG,'l_option_return : ' l_option_return);

            --Fetch DO_PICK_RELEASE request Id into l_request_id
            l_request_id   :=
                /*fnd_request.submit_request (
                   application   => 'XXDO',
                   program       => 'DO_PICK_RELEASE',
                   argument1     => 'Commit Mode',
                   argument2     => rec_cursor.ship_from_org_id,
                   argument3     => NULL,
                    argument4     => NULL,
                    argument5     => NULL,
                   argument6     => NULL,
                   argument7     => NULL,
                    argument8     => NULL,
                     argument9     => NULL,
                     argument10    => NULL,
                     argument11     => rec_cursor.order_number,
                      argument12     =>l_min_line_pick_pct,
                      argument13     =>l_min_unit_pick_pct,
                      argument14     =>l_min_line_cnt_pick_pct,
                      argument15    => l_min_line_unit_pick_pct,
                      argument16     =>1,
                      argument17     =>0,
                      argument18     =>NULL,
                     argument19    => NULL ,
                     ----------------------------------------------------------------------------
                     -- Added By Siva B on 04/25 to support a new parameter in pick release
                     ----------------------------------------------------------------------------
                     argument20 => NULL,
                     --------------------------
                     -- End of change By Siva B
                     --------------------------
                   description   => NULL,
                   start_time    => NULL);*/
                 apps.fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'DO_PICK_RELEASE',
                    description   => 'Pick Release - Deckers',
                    start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                    sub_request   => FALSE,
                    argument1     => 'Commit Mode',                    -- Mode
                    argument2     => rec_cursor.ship_from_org_id,
                    --organization
                    argument3     => NULL,                             --brand
                    argument4     => NULL,                           --channel
                    argument5     => NULL,                          --fromdate
                    argument6     => NULL,                            --todate
                    argument7     => NULL,                --pv_include_exclude
                    argument8     => NULL,                              --temp
                    argument9     => NULL,                     --Exclude Style
                    argument10    => NULL,                              --temp
                    argument11    => NULL,               --Exclude Style Color
                    argument12    => NULL,                              --temp
                    argument13    => NULL,                       --l_inc_style
                    argument14    => NULL,                              --temp
                    argument15    => NULL,                 --l_inc_style_color
                    argument16    => NULL,                              --temp
                    argument17    => NULL,                          --division
                    argument18    => NULL,                        --department
                    argument19    => NULL,                      --Order source
                    argument20    => NULL,                        --order type
                    argument21    => NULL,                  --Customer to Pick
                    argument22    => NULL,                                --po
                    argument23    => rec_cursor.order_number,   --order_number
                    argument24    => l_min_line_pick_pct,
                    --Minimum Line Pick Percent
                    argument25    => l_min_unit_pick_pct,
                    --Minimum Unit Pick Percent
                    argument26    => l_min_line_cnt_pick_pct,
                    --Minumum Percent Lines in a Style/Color to be Eligible
                    argument27    => l_min_line_unit_pick_pct,
                    --Minumum Percent Units in a Style/Color to be Eligible
                    argument28    => '1',                  --Number of workers
                    argument29    => '0',                        --Debug Level
                    argument30    => NULL,                         --Pick Type
                    argument31    => NULL                    --Customer Number
                                         );
            COMMIT;

            --Concatenate request Ids with warehouse names
            SELECT v_concat || rec_cursor.organization_name || ' : ' || l_request_id || ' ~ '
              INTO v_concat
              FROM DUAL;
        END LOOP;

        --Assign v_concat to an out variable
        p_req_id_str   := v_concat;
        fnd_file.put_line (fnd_file.LOG,
                           'Request ID string : ' || p_req_id_str);
    EXCEPTION
        WHEN OTHERS
        THEN
            l_out_num_ret_status   := 1;
            l_out_chr_ret_message   :=
                   'Unexpected Error in XXDO_PICK_RELEASE_FOR_ORDER: '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception raised in XXDO_PICK_RELEASE_FOR_ORDER procedure : '
                || SQLERRM);
    END xxdo_pick_release_for_order;
END xxdo_pick_release_order_pkg;
/
