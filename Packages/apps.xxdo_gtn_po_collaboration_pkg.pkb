--
-- XXDO_GTN_PO_COLLABORATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_GTN_PO_COLLABORATION_PKG"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : Purchasing
    --  Project         : GT Nexus Phase 2
    --  Description     : Package for Purchase Order Collaboration
    --  Module          : xxdo_gtn_po_collaboration_pkg
    --  File            : xxdo_gtn_po_collaboration_pkg.pkb
    --  Schema          : APPS
    --  Date            : 16-Oct-2014
    --  Version         : 1.0
    --  Author(s)       : Anil Suddapalli [ Suneratech Consulting]
    --  Purpose         : Package used to split the PO Lines based on the split flag sourced from GTN.
    --                        This package is invoked by SOA when there is Split in GTN
    --  dependency      :
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                                   Description
    --  ----------      --------------      -----   --------------------                     ------------------
    --  16-Oct-2014    Anil Suddapalli      1.0                                             Initial Version
    --  24_Nov-2014                         1.1      Added ASN update
    --  06-Jan-2015                         1.2      Added Dropship Order Functioanlity
    --  20-Jan-2015                         1.3      Added Update Dropship PO order price
    --  22-Jan-2015                         1.4      Added Promised Date Changes
    --  03-Mar-2015                         1.5      Added POC Flag changes and new Procedure invoked by SOA
    --  13-Mar-2015                         1.6      Removed Approved flag condition in Update PO line, Shipment procedures
    --  30-Mar-2015                         1.7      Added Approval API
    --  08-Apr-2015                         1.8      Factory code changes at PO line level
    --  09-Apr-2015                         1.9      Added Workflow Backgrund Process to remove dependency on schedule of program
    --  14-Apr-2015                         2.0      BT Retrofit changes
    --  23-Apr-2015                         2.1      BT Retrofit changes - Modified FOB changes at PO line level
    --  21-May-2015                         2.2      BT - Replaced MO:Operating Unit with Security Profile
    --  10-Jun-2015                         2.3      BT - Updating Request date on SO and defaulting EXTERNAL as source type
    --  10-Jun-2015                         2.4      BT - Factory code change - Updating last_update_date, which triggers POA
    --  12-Jun-2015                         2.5      BT - Change to check SO Credit Check Failure hold
    --  29-Jul-2015                         2.6      Launch approval flag as N in Update PO API, we are approving only at end of the POC file
    --                                               Also, we are asking SOA to invoke Approval API at end of the POC file, same as in R12.0.6
    --  14-Sep-2015                         2.7      Check if POC change is for Split type or change in only DFFs and update only DFF values if it is DFF change
    --  16-Sep-2015                         2.8      Including Special VAS Split scenario
    --  20-Jul-2016                         2.9      INC0306175 - Commenting the logic of populating
    -- receipt quantity to the new split line which is getting created.
    --  ###################################################################################

    ------------------------------------------------------------------------------------------
    --Global Variables Declaration
    ------------------------------------------------------------------------------------------
    gn_resp_id                              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id                         NUMBER := apps.fnd_global.resp_appl_id;
    --gn_user_name                CONSTANT VARCHAR2 (240) := 'LEONE';
    gv_mo_profile_option_name      CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name         CONSTANT VARCHAR2 (240)
                                                := 'Deckers Purchasing User' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management User' ;

    /*
    This is the driving procedure, where SOA calls for each record in the POC file
    */

    PROCEDURE main_proc_validate_poc_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_item_key IN VARCHAR2, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pv_exfactory_date IN VARCHAR2, pn_unit_price IN NUMBER
                                           , pv_new_promised_date IN VARCHAR2, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2)
    IS
        ln_instr               NUMBER;
        ln_line_num            NUMBER;
        ln_shipment_num        NUMBER;
        ln_distrb_num          NUMBER;
        ln_user_id             NUMBER;
        ln_org_id              NUMBER;
        ln_cnt                 NUMBER := 1;
        ln_substr              NUMBER := 1;
        ln_resp_id             NUMBER;
        ln_resp_appl_id        NUMBER;
        pd_new_promised_date   DATE;
        pd_exfactory_date      DATE;
        ln_order_type_id       NUMBER;
        lv_cancel_flag         VARCHAR2 (30);
        lv_closed_code         VARCHAR2 (30);
        lv_approved_flag       VARCHAR2 (30);
        ln_count               NUMBER;
        lv_type_of_change      VARCHAR2 (10);
    BEGIN
        DBMS_OUTPUT.put_line (
               'In BEGIN start time:'
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));

        pd_exfactory_date   := TO_DATE (pv_exfactory_date, 'MM/DD/YYYY');
        pd_new_promised_date   :=
            TO_DATE (pv_new_promised_date, 'MM/DD/YYYY');


        BEGIN
            SELECT user_id
              INTO ln_user_id
              FROM apps.fnd_user fu, apps.po_headers_all pha
             WHERE     pha.segment1 = pv_po_number
                   AND fu.employee_id = pha.agent_id
                   AND ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting User Id in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        IF ln_user_id IS NULL
        THEN
            SELECT user_id
              INTO ln_user_id
              FROM apps.fnd_user
             WHERE user_name = 'SYSADMIN';
        END IF;


        --splitting item key to 3 different variables line_num, shipment_num, distribution_num
        WHILE (ln_cnt < 3)
        LOOP
            ln_instr   :=
                INSTR (pv_item_key, '.', 1,
                       ln_cnt);

            IF (ln_cnt = 1)
            THEN
                ln_line_num   :=
                    SUBSTR (pv_item_key, ln_substr, ln_instr - 1);
                ln_substr   := ln_instr;
            ELSIF (ln_cnt = 2)
            THEN
                ln_shipment_num   :=
                    SUBSTR (pv_item_key,
                            ln_substr + 1,
                            ln_instr - ln_substr - 1);
                ln_distrb_num   := SUBSTR (pv_item_key, ln_instr + 1);
            END IF;

            ln_cnt   := ln_cnt + 1;
        END LOOP;


        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND plla.shipment_num = TO_NUMBER (ln_shipment_num)
                   AND pla.line_num = TO_NUMBER (ln_line_num)
                   AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Count of PO in Main procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;



        BEGIN
            SELECT pla.cancel_flag, plla.closed_code, pha.approved_flag
              INTO lv_cancel_flag, lv_closed_code, lv_approved_flag
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND plla.shipment_num = TO_NUMBER (ln_shipment_num)
                   AND pla.line_num = TO_NUMBER (ln_line_num)
                   AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Cancel, Closed, Aprroved flags in Main procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;



        IF (NVL (lv_cancel_flag, 'N') <> 'Y' AND NVL (lv_closed_code, 'OPEN') = 'OPEN' AND (NVL (lv_approved_flag, 'N') IN ('Y', 'R')) AND ln_count <> 0)
        THEN
            --Check if there is change in the Qty/Unit Price/Promised Date/DFFs

            lv_type_of_change   :=
                get_type_of_change (pn_err_code,
                                    pv_err_message,
                                    TO_NUMBER (ln_line_num),
                                    TO_NUMBER (ln_shipment_num),
                                    TO_NUMBER (ln_distrb_num),
                                    pv_po_number,
                                    pn_quantity,
                                    pn_unit_price,
                                    pd_new_promised_date);

            /* If there is only change in the DFFs, then we just update PO DFF values
                Else, we go with updating PO lines using APIs
            */
            ln_order_type_id   :=
                check_order (pv_po_number, TO_NUMBER (ln_line_num));

            IF (UPPER (pv_split_flag) = 'FALSE' AND lv_type_of_change = 'DFF')
            THEN
                --     dbms_output.put_line('type:'||lv_type_of_change);
                --     dbms_output.put_line('pv_split_flag:'||pv_split_flag);

                update_po_dffs (pn_err_code, pv_err_message, ln_user_id,
                                TO_NUMBER (ln_line_num), TO_NUMBER (ln_shipment_num), TO_NUMBER (ln_distrb_num), pv_po_number, pv_shipmethod, pd_exfactory_date
                                , pv_freight_pay_party, ln_order_type_id);
            ELSE
                --     dbms_output.put_line('type1:'||lv_type_of_change);
                --     dbms_output.put_line('pv_split_flag1:'||pv_split_flag);
                --     dbms_output.put_line('ln_order_type_id:'||ln_order_type_id);



                IF (ln_order_type_id = 0)                 -- Process Normal PO
                THEN
                    process_normal_po (pn_err_code,
                                       pv_err_message,
                                       ln_user_id,
                                       TO_NUMBER (ln_line_num),
                                       TO_NUMBER (ln_shipment_num),
                                       TO_NUMBER (ln_distrb_num),
                                       pv_split_flag,
                                       pv_po_number,
                                       pv_shipmethod,
                                       pn_quantity,
                                       pd_exfactory_date,
                                       pn_unit_price,
                                       pd_new_promised_date,
                                       pv_freight_pay_party,
                                       pv_original_line_flag);
                ELSIF (ln_order_type_id = 1)            -- Process Dropship PO
                THEN
                    process_dropship_po (pn_err_code,
                                         pv_err_message,
                                         ln_user_id,
                                         TO_NUMBER (ln_line_num),
                                         TO_NUMBER (ln_shipment_num),
                                         TO_NUMBER (ln_distrb_num),
                                         pv_split_flag,
                                         pv_po_number,
                                         pv_shipmethod,
                                         pn_quantity,
                                         pd_exfactory_date,
                                         pn_unit_price,
                                         pd_new_promised_date,
                                         pv_freight_pay_party,
                                         pv_original_line_flag);
                ELSIF (ln_order_type_id = 2)         -- Process Special VAS PO
                THEN
                    DBMS_OUTPUT.put_line ('Special VAS');

                    process_special_vas_po (pn_err_code,
                                            pv_err_message,
                                            ln_user_id,
                                            TO_NUMBER (ln_line_num),
                                            TO_NUMBER (ln_shipment_num),
                                            TO_NUMBER (ln_distrb_num),
                                            pv_split_flag,
                                            pv_po_number,
                                            pv_shipmethod,
                                            pn_quantity,
                                            pd_exfactory_date,
                                            pn_unit_price,
                                            pd_new_promised_date,
                                            pv_freight_pay_party,
                                            pv_original_line_flag);
                END IF;
            END IF;
        ELSIF ln_count = 0
        THEN
            pn_err_code      := 1;
            pv_err_message   := 'Record doesnt exist in Oracle';
        ELSE
            pn_err_code   := 1;
            pv_err_message   :=
                'POC Failed due to one of the reasons, either PO is Cancelled/Closed/Not approved';
        END IF;

        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
        THEN
            COMMIT;
            pn_err_code      := 0;
            pv_err_message   := 'SUCCESS';
        END IF;

        DBMS_OUTPUT.put_line (
            'In BEGIN end time:' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in validate poc line'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END main_proc_validate_poc_line;

    /*
    update_po_line procedure is used to update PO line information using standard API, invoked from
    process_normal_po/process_dropship_po procedure
    */

    PROCEDURE update_po_line (pn_err_code            OUT NUMBER,
                              pv_err_message         OUT VARCHAR2,
                              pn_user_id                 NUMBER,
                              pn_line_num                NUMBER,
                              pn_shipment_num            NUMBER,
                              pv_po_number               VARCHAR2,
                              pn_quantity                NUMBER,
                              pn_unit_price              NUMBER,
                              pd_new_promised_date       DATE)
    IS
        -- Cursor fetches the PO information that is Approved, Not cancelled, OPEN, and Not partially received
        CURSOR cur_po_update IS
            SELECT pha.segment1 po_number, pha.revision_num, pha.po_header_id,
                   pha.authorization_status, pla.po_line_id, pla.line_num,
                   pha.org_id, pla.unit_price, pola.line_location_id,
                   pola.shipment_num, pola.quantity, pola.promised_date,
                   pola.need_by_date, pha.closed_code
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all pola
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = pola.po_line_id
                   AND NVL (pola.cancel_flag, 'N') <> 'Y'
                   AND NVL (pola.closed_code, 'OPEN') = 'OPEN'
                   --AND NVL (pola.quantity_received, 0) = 0
                   --AND NVL (pola.quantity_billed, 0) = 0
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num
                   AND pha.type_lookup_code = 'STANDARD';

        --TYPE p_api_errors is TABLE OF VARCHAR2(1000) index by binary_integer;
        ln_result          NUMBER;
        l_api_errors       apps.po_api_errors_rec_type;        --P_API_ERRORS;
        ln_revision_num    NUMBER;
        ld_promised_date   DATE;
        ld_need_by_date    DATE;
        ln_price           apps.po_lines_all.unit_price%TYPE;
        ln_quantity        apps.po_line_locations_all.quantity%TYPE;
        ln_resp_id         NUMBER;
        ln_resp_appl_id    NUMBER;
        ln_org_id          NUMBER;
    BEGIN
        --DBMS_OUTPUT.put_line ('In Update PO Line');

        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.po_headers_all
             WHERE segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.mo_global.init ('PO');
        apps.mo_global.set_policy_context ('S', ln_org_id);

        FOR rec_po_update IN cur_po_update
        LOOP
            IF pd_new_promised_date IS NOT NULL
            THEN
                ld_promised_date   := pd_new_promised_date;
            ELSE
                ld_promised_date   := rec_po_update.promised_date;
            END IF;

            ln_quantity   := pn_quantity;
            ln_price      := pn_unit_price;

            --         DBMS_OUTPUT.put_line ('Calling po_change_api1_s.update_po To Update PO');
            --         DBMS_OUTPUT.put_line ('===================================');
            --         DBMS_OUTPUT.put_line ('Retrieving the Current Revision Number of PO');

            BEGIN
                SELECT revision_num
                  INTO ln_revision_num
                  FROM apps.po_headers_all
                 WHERE segment1 = rec_po_update.po_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error in while getting revision number in update po line'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            ln_result     :=
                apps.po_change_api1_s.update_po (
                    x_po_number             => rec_po_update.po_number, --Enter the PO Number
                    x_release_number        => NULL,   --Enter the Release Num
                    x_revision_number       => ln_revision_num, --Enter the Revision Number
                    x_line_number           => rec_po_update.line_num, --Enter the Line Number
                    x_shipment_number       => rec_po_update.shipment_num, --Enter the Shipment Number
                    new_quantity            => ln_quantity, --Enter the new quantity
                    new_price               => ln_price, --Enter the new price,
                    new_promised_date       => ld_promised_date, -- New Promise Date coming from POC interface
                    new_need_by_date        => ld_promised_date, --this may happen in future, so just replace with ld_promised_date when needed.
                    launch_approvals_flag   => 'N', -- Change: 2.6 - Pass as 'N', to remove Auto approval, we are only approving at end of the POC file
                    update_source           => NULL,
                    VERSION                 => '1.0',
                    x_override_date         => NULL,
                    x_api_errors            => l_api_errors,
                    p_buyer_name            => NULL,
                    p_secondary_quantity    => NULL,
                    p_preferred_grade       => NULL,
                    p_org_id                => rec_po_update.org_id);

            BEGIN
                UPDATE apps.po_lines_all               -- POC Negotiation flag
                   SET attribute13 = 'True', attribute11 = ln_price - (NVL (attribute8, 0) + NVL (attribute9, 0))
                 WHERE     line_num = rec_po_update.line_num
                       AND po_header_id =
                           (SELECT po_header_id
                              FROM apps.po_headers_all
                             WHERE segment1 = rec_po_update.po_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error while updating POC Negotiation flag in update po line proc'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;
        --         DBMS_OUTPUT.put_line (ln_result);

        --                 IF (ln_result = 1)
        --                 THEN
        --                    DBMS_OUTPUT.put_line ('Successfully update the PO :=>');
        --                 END IF;

        --                 IF (ln_result <> 1)
        --                 THEN
        --                    DBMS_OUTPUT.put_line
        --                                  ('Failed to update the PO Due to Following Reasons');

        --                     Display the errors
        --                    FOR j IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
        --                    LOOP
        --                       DBMS_OUTPUT.put_line (l_api_errors.MESSAGE_TEXT (j));
        --                    END LOOP;
        --                 END IF;

        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in update po line proc'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_po_line;

    /*
    update_shipment_line procedure is used to update Shipment information of PO line using private API, invoked from
    process_normal_po/process_dropship_po/salesorder_line procedure
    */
    PROCEDURE update_shipment_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_source VARCHAR2, pn_user_id NUMBER, pn_original_line_num NUMBER, pn_line_num NUMBER, pn_orig_shipment_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pv_shipmethod VARCHAR2, pd_exfactory_date DATE, pv_freight_pay_party VARCHAR2
                                    , pd_new_promised_date DATE)
    IS
        ln_line_location_id      NUMBER;
        lv_rowid                 VARCHAR2 (4000);
        lv_conf_exfactory_date   VARCHAR2 (4000);
        lv_orig_exfactory_date   VARCHAR2 (4000);
        lv_attribute1            VARCHAR2 (4000);
        lv_attribute2            VARCHAR2 (4000);
        lv_attribute3            VARCHAR2 (4000);
        lv_attribute4            VARCHAR2 (4000);
        lv_attribute6            VARCHAR2 (4000);
        lv_attribute8            VARCHAR2 (4000);
        lv_attribute9            VARCHAR2 (4000);
        lv_attribute11           VARCHAR2 (4000);
        lv_attribute12           VARCHAR2 (4000);
        lv_attribute13           VARCHAR2 (4000);
        lv_attribute14           VARCHAR2 (4000);
        lv_attribute15           VARCHAR2 (4000);
        ln_resp_id               NUMBER;
        ln_resp_appl_id          NUMBER;
        ln_org_id                NUMBER;
        lv_attribute_category    VARCHAR2 (4000);
        ld_promised_date         DATE;


        CURSOR cur_po_line_locs IS
            SELECT plla.ROWID, plla.*
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND NVL (plla.cancel_flag, 'N') <> 'Y'
                   AND NVL (plla.closed_code, 'OPEN') = 'OPEN'
                   AND pla.line_num = pn_line_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
    BEGIN
        --DBMS_OUTPUT.put_line ('In Update PO Line');

        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.po_headers_all
             WHERE segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.mo_global.init ('PO');
        apps.mo_global.set_policy_context ('S', ln_org_id);

        lv_conf_exfactory_date   :=
            TO_CHAR (
                TO_DATE (TO_CHAR (pd_exfactory_date, 'DD-MON-YYYY'),
                         'DD-MON-RRRR'),
                'RRRR/MM/DD HH24:MI:SS');

        FOR rec_po_line_locs IN cur_po_line_locs
        LOOP
            IF (rec_po_line_locs.attribute8 IS NULL) -- Updates the Orig Conf Exfactory Date with Exfactory Date when the value is NULL for the first time
            THEN
                lv_orig_exfactory_date   := lv_conf_exfactory_date; --TO_CHAR(TO_DATE(lv_conf_exfactory_date,'DD-MON-RRRR'),'RRRR/MM/DD HH24:MI:SS');
            --In BT OrigconfExfactory format is same as Exfactory Date

            ELSE
                lv_orig_exfactory_date   := rec_po_line_locs.attribute8;
            END IF;

            lv_attribute_category   := rec_po_line_locs.attribute_category;
            lv_attribute1           := rec_po_line_locs.attribute1;
            lv_attribute2           := rec_po_line_locs.attribute2;
            lv_attribute3           := rec_po_line_locs.attribute3;
            lv_attribute4           := rec_po_line_locs.attribute4;
            lv_attribute6           := rec_po_line_locs.attribute6;
            lv_attribute8           := rec_po_line_locs.attribute8;
            lv_attribute9           := rec_po_line_locs.attribute9;
            lv_attribute11          := rec_po_line_locs.attribute11;
            lv_attribute12          := rec_po_line_locs.attribute12;
            lv_attribute13          := rec_po_line_locs.attribute13;
            lv_attribute14          := rec_po_line_locs.attribute14;
            lv_attribute15          := rec_po_line_locs.attribute15;

            IF pd_new_promised_date IS NOT NULL
            THEN
                ld_promised_date   := pd_new_promised_date;
            ELSE
                ld_promised_date   := rec_po_line_locs.promised_date;
            END IF;



            IF (UPPER (pv_source) = 'FROM INSERT')
            THEN
                BEGIN
                    SELECT plla.attribute1, plla.attribute2, plla.attribute3,
                           plla.attribute4, plla.attribute6, plla.attribute8,
                           plla.attribute9, plla.attribute_category, plla.attribute11,
                           plla.attribute12, plla.attribute13, plla.attribute14,
                           plla.attribute15, plla.promised_date
                      INTO lv_attribute1, lv_attribute2, lv_attribute3, lv_attribute4,
                                        lv_attribute6, lv_attribute8, lv_attribute9,
                                        lv_attribute_category, lv_attribute11, lv_attribute12,
                                        lv_attribute13, lv_attribute14, lv_attribute15,
                                        ld_promised_date
                      FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
                     WHERE     1 = 1
                           AND pla.line_num = pn_original_line_num
                           AND plla.shipment_num = pn_orig_shipment_num
                           AND pha.segment1 = pv_po_number
                           AND pla.po_line_id = plla.po_line_id
                           AND pha.po_header_id = pla.po_header_id;

                    IF (lv_attribute8 IS NULL) -- Updates the Orig Conf Exfactory Date with Exfactory Date
                    THEN -- when the value of OriginalLineflag in Orginal line is NULL for the New line
                        lv_orig_exfactory_date   := lv_conf_exfactory_date; --TO_CHAR(TO_DATE(lv_conf_exfactory_date,'DD-MON-RRRR'),'RRRR/MM/DD HH24:MI:SS');
                    ELSE
                        lv_orig_exfactory_date   := lv_attribute8;
                    END IF;

                    IF pd_new_promised_date IS NOT NULL
                    THEN
                        ld_promised_date   := pd_new_promised_date;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error in update shipment line procedure while getting attribute parameters'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;
            END IF;

            apps.po_line_locations_pkg_s2.update_row (
                rec_po_line_locs.ROWID,
                rec_po_line_locs.line_location_id,
                SYSDATE,                   --X_Last_Update_Date              ,
                pn_user_id,                --X_Last_Updated_By               ,
                rec_po_line_locs.po_header_id,
                rec_po_line_locs.po_line_id,
                pn_user_id,                --X_Last_Update_Login             ,
                rec_po_line_locs.quantity,
                rec_po_line_locs.quantity_received,
                rec_po_line_locs.quantity_accepted,
                rec_po_line_locs.quantity_rejected,
                rec_po_line_locs.quantity_billed,
                rec_po_line_locs.quantity_cancelled,
                rec_po_line_locs.unit_meas_lookup_code,
                rec_po_line_locs.po_release_id,
                rec_po_line_locs.ship_to_location_id,
                rec_po_line_locs.ship_via_lookup_code,
                ld_promised_date,                              -- Need by date
                ld_promised_date, -- New Promise Date coming from POC interface
                rec_po_line_locs.last_accept_date,
                rec_po_line_locs.price_override,
                rec_po_line_locs.encumbered_flag,
                rec_po_line_locs.encumbered_date,
                rec_po_line_locs.fob_lookup_code,
                rec_po_line_locs.freight_terms_lookup_code,
                rec_po_line_locs.taxable_flag,
                rec_po_line_locs.tax_code_id,
                rec_po_line_locs.tax_user_override_flag,
                rec_po_line_locs.calculate_tax_flag,
                rec_po_line_locs.from_header_id,
                rec_po_line_locs.from_line_id,
                rec_po_line_locs.from_line_location_id,
                rec_po_line_locs.start_date,
                rec_po_line_locs.end_date,
                rec_po_line_locs.lead_time,
                rec_po_line_locs.lead_time_unit,
                rec_po_line_locs.price_discount,
                rec_po_line_locs.terms_id,
                rec_po_line_locs.approved_flag,
                rec_po_line_locs.approved_date,
                rec_po_line_locs.closed_flag,
                rec_po_line_locs.cancel_flag,
                rec_po_line_locs.cancelled_by,
                rec_po_line_locs.cancel_date,
                rec_po_line_locs.cancel_reason,
                rec_po_line_locs.firm_status_lookup_code,
                lv_attribute_category,
                lv_attribute1,
                lv_attribute2,
                lv_attribute3,
                lv_attribute4,                --sysdate+2                    ,
                lv_conf_exfactory_date,                  -- New Exfactory Date
                lv_attribute6,
                pv_freight_pay_party,                 -- New Freight Pay Party
                lv_orig_exfactory_date,
                lv_attribute9,
                pv_shipmethod,                          -- New Shipment Method
                lv_attribute11,
                lv_attribute12,
                lv_attribute13,
                lv_attribute14,
                lv_attribute15,
                rec_po_line_locs.inspection_required_flag,
                rec_po_line_locs.receipt_required_flag,
                rec_po_line_locs.qty_rcv_tolerance,
                rec_po_line_locs.qty_rcv_exception_code,
                rec_po_line_locs.enforce_ship_to_location_code,
                rec_po_line_locs.allow_substitute_receipts_flag,
                rec_po_line_locs.days_early_receipt_allowed,
                rec_po_line_locs.days_late_receipt_allowed,
                rec_po_line_locs.receipt_days_exception_code,
                rec_po_line_locs.invoice_close_tolerance,
                rec_po_line_locs.receive_close_tolerance,
                rec_po_line_locs.ship_to_organization_id,
                rec_po_line_locs.shipment_num,
                rec_po_line_locs.source_shipment_id,
                rec_po_line_locs.shipment_type,
                rec_po_line_locs.closed_code,
                rec_po_line_locs.ussgl_transaction_code,
                rec_po_line_locs.government_context,
                rec_po_line_locs.receiving_routing_id,
                rec_po_line_locs.accrue_on_receipt_flag,
                rec_po_line_locs.closed_reason,
                rec_po_line_locs.closed_date,
                rec_po_line_locs.closed_by,
                rec_po_line_locs.global_attribute_category,
                rec_po_line_locs.global_attribute1,
                rec_po_line_locs.global_attribute2,
                rec_po_line_locs.global_attribute3,
                rec_po_line_locs.global_attribute4,
                rec_po_line_locs.global_attribute5,
                rec_po_line_locs.global_attribute6,
                rec_po_line_locs.global_attribute7,
                rec_po_line_locs.global_attribute8,
                rec_po_line_locs.global_attribute9,
                rec_po_line_locs.global_attribute10,
                rec_po_line_locs.global_attribute11,
                rec_po_line_locs.global_attribute12,
                rec_po_line_locs.global_attribute13,
                rec_po_line_locs.global_attribute14,
                rec_po_line_locs.global_attribute15,
                rec_po_line_locs.global_attribute16,
                rec_po_line_locs.global_attribute17,
                rec_po_line_locs.global_attribute18,
                rec_po_line_locs.global_attribute19,
                rec_po_line_locs.global_attribute20,
                rec_po_line_locs.country_of_origin_code,
                rec_po_line_locs.match_option,
                rec_po_line_locs.note_to_receiver,
                rec_po_line_locs.secondary_unit_of_measure,
                rec_po_line_locs.secondary_quantity,
                rec_po_line_locs.preferred_grade,
                rec_po_line_locs.secondary_quantity_received,
                rec_po_line_locs.secondary_quantity_accepted,
                rec_po_line_locs.secondary_quantity_rejected,
                rec_po_line_locs.secondary_quantity_cancelled,
                rec_po_line_locs.consigned_flag,
                rec_po_line_locs.amount,
                rec_po_line_locs.transaction_flow_header_id,
                rec_po_line_locs.manual_price_change_flag);
        END LOOP;

        COMMIT;
    --DBMS_OUTPUT.put_line (' End Time  ');
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in update shipment line procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_shipment_line;

    /*
    insert_po_line procedure is used to insert new PO line using private API, invoked from
    process_normal_po procedure
    */
    PROCEDURE insert_po_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_po_number VARCHAR2, pv_shipmethod VARCHAR2, pn_quantity NUMBER, pd_exfactory_date DATE, pn_unit_price NUMBER, pd_new_promised_date DATE
                              , pv_freight_pay_party VARCHAR2, xn_line_num OUT NUMBER, xn_shipment_num OUT NUMBER)
    IS
        ln_line_id            NUMBER;
        ln_line_location_id   NUMBER;
        ln_line_num           NUMBER;
        ln_shipment_num       NUMBER;
        lv_rowid              VARCHAR2 (4000);
        pn_vendor_id          NUMBER;
        lb_autocreated_ship   BOOLEAN;

        CURSOR cur_po_insert_lines IS
            SELECT pha.vendor_id, pla.*, plla.shipment_type,
                   plla.ship_to_location_id, ship_to_organization_id, need_by_date,
                   promised_date, receipt_required_flag, invoice_close_tolerance,
                   receive_close_tolerance, accrue_on_receipt_flag
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND line_num = pn_line_num
                   AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;


        ln_resp_id            NUMBER;
        ln_resp_appl_id       NUMBER;
        ln_org_id             NUMBER;
    BEGIN
        --DBMS_OUTPUT.put_line ('In Update PO Line');

        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.po_headers_all
             WHERE segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.mo_global.init ('PO');
        apps.mo_global.set_policy_context ('S', ln_org_id);

        --  DBMS_OUTPUT.put_line (' Start Time  ');

        --fnd_global.apps_initialize (<userid>, <applid>,<appluserid>);

        BEGIN
            SELECT apps.po_lines_s.NEXTVAL INTO ln_line_id FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in while getting line id in insert po line'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT apps.po_line_locations_s.NEXTVAL
              INTO ln_line_location_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in while getting  line location id in insert po line'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT MAX (line_num) + 1
              INTO ln_line_num
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.segment1 = pv_po_number
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in while getting  line num in insert po line'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        FOR rec_po_insert_lines IN cur_po_insert_lines
        LOOP
            BEGIN
                apps.PO_LINES_SV3.insert_line (
                    lv_Rowid,
                    ln_line_id,
                    SYSDATE,
                    pn_user_id,
                    rec_po_insert_lines.Po_Header_Id,
                    rec_po_insert_lines.Line_Type_Id,
                    ln_line_num,
                    pn_user_id,
                    SYSDATE,
                    pn_user_id,
                    rec_po_insert_lines.Item_Id,
                    rec_po_insert_lines.Item_Revision,
                    rec_po_insert_lines.Category_Id,
                    rec_po_insert_lines.Item_Description,
                    rec_po_insert_lines.Unit_Meas_Lookup_Code,
                    rec_po_insert_lines.Quantity_Committed,
                    rec_po_insert_lines.Committed_Amount,
                    rec_po_insert_lines.Allow_Price_Override_Flag,
                    rec_po_insert_lines.Not_To_Exceed_Price,
                    rec_po_insert_lines.list_price_per_unit,
                    pn_unit_price,                         --   New Unit Price
                    pn_quantity,                             --   New Quantity
                    rec_po_insert_lines.Un_Number_Id,
                    rec_po_insert_lines.Hazard_Class_Id,
                    rec_po_insert_lines.Note_To_Vendor,
                    rec_po_insert_lines.From_Header_Id,
                    rec_po_insert_lines.From_Line_Id,
                    rec_po_insert_lines.from_line_location_id,
                    rec_po_insert_lines.Min_Order_Quantity,
                    rec_po_insert_lines.Max_Order_Quantity,
                    rec_po_insert_lines.Qty_Rcv_Tolerance,
                    rec_po_insert_lines.Over_Tolerance_Error_Flag,
                    rec_po_insert_lines.Market_Price,
                    rec_po_insert_lines.Unordered_Flag,
                    rec_po_insert_lines.Closed_Flag,
                    rec_po_insert_lines.User_Hold_Flag,
                    rec_po_insert_lines.Cancel_Flag,
                    rec_po_insert_lines.Cancelled_By,
                    rec_po_insert_lines.Cancel_Date,
                    rec_po_insert_lines.Cancel_Reason,
                    rec_po_insert_lines.Firm_Status_Lookup_Code,
                    rec_po_insert_lines.Firm_Date,
                    rec_po_insert_lines.Vendor_Product_Num,
                    rec_po_insert_lines.Contract_Num,
                    rec_po_insert_lines.Taxable_Flag,
                    rec_po_insert_lines.Tax_Code_Id,
                    rec_po_insert_lines.Type_1099,
                    rec_po_insert_lines.Capital_Expense_Flag,
                    rec_po_insert_lines.Negotiated_By_Preparer_Flag,
                    rec_po_insert_lines.Attribute_Category,
                    rec_po_insert_lines.Attribute1,
                    rec_po_insert_lines.Attribute2,
                    rec_po_insert_lines.Attribute3,
                    rec_po_insert_lines.Attribute4,
                    rec_po_insert_lines.Attribute5,
                    rec_po_insert_lines.Attribute6,
                    rec_po_insert_lines.Attribute7,
                    rec_po_insert_lines.Attribute8,
                    rec_po_insert_lines.Attribute9,
                    rec_po_insert_lines.Attribute10,
                    rec_po_insert_lines.Reference_Num,
                      pn_unit_price
                    - (NVL (rec_po_insert_lines.Attribute8, 0) + NVL (rec_po_insert_lines.Attribute9, 0)),
                    rec_po_insert_lines.Attribute12,
                    'True',
                    rec_po_insert_lines.Attribute14,
                    rec_po_insert_lines.Attribute15,
                    rec_po_insert_lines.Min_Release_Amount,
                    rec_po_insert_lines.Price_Type_Lookup_Code,
                    rec_po_insert_lines.Closed_Code,
                    rec_po_insert_lines.Price_Break_Lookup_Code,
                    rec_po_insert_lines.Ussgl_Transaction_Code,
                    rec_po_insert_lines.Government_Context,
                    rec_po_insert_lines.Closed_Date,
                    rec_po_insert_lines.Closed_Reason,
                    rec_po_insert_lines.Closed_By,
                    rec_po_insert_lines.Transaction_Reason_Code,
                    NULL, --rec_po_insert_lines.revise_header                  ,
                    NULL, --rec_po_insert_lines.revision_num                   ,
                    NULL, --rec_po_insert_lines.revised_date                   ,
                    NULL, --rec_po_insert_lines.approved_flag                  ,
                    NULL, --rec_po_insert_lines.header_row_id                  ,
                    rec_po_insert_lines.shipment_type, --VARCHAR2, NEED TO FIND shipment_type
                    rec_po_insert_lines.ship_to_location_id,
                    rec_po_insert_lines.ship_to_organization_id,
                    rec_po_insert_lines.need_by_date,
                    rec_po_insert_lines.promised_date, --       New promised date
                    rec_po_insert_lines.receipt_required_flag,
                    rec_po_insert_lines.invoice_close_tolerance,
                    rec_po_insert_lines.receive_close_tolerance,
                    NULL, --rec_po_insert_lines.planned_item_flag              ,
                    'N', --rec_po_insert_lines.outside_operation_flag         ,
                    NULL, --rec_po_insert_lines.destination_type_code          ,
                    NULL, --rec_po_insert_lines.expense_accrual_code           ,
                    NULL, --rec_po_insert_lines.dist_blk_status                ,
                    rec_po_insert_lines.accrue_on_receipt_flag,
                    'Y', --rec_po_insert_lines.ok_to_autocreate_ship          ,
                    lb_autocreated_ship, --rec_po_insert_lines.autocreated_ship               ,
                    LN_LINE_LOCATION_ID,
                    rec_po_insert_lines.vendor_id,
                    rec_po_insert_lines.Global_Attribute_Category,
                    rec_po_insert_lines.Global_Attribute1,
                    rec_po_insert_lines.Global_Attribute2,
                    rec_po_insert_lines.Global_Attribute3,
                    rec_po_insert_lines.Global_Attribute4,
                    rec_po_insert_lines.Global_Attribute5,
                    rec_po_insert_lines.Global_Attribute6,
                    rec_po_insert_lines.Global_Attribute7,
                    rec_po_insert_lines.Global_Attribute8,
                    rec_po_insert_lines.Global_Attribute9,
                    rec_po_insert_lines.Global_Attribute10,
                    rec_po_insert_lines.Global_Attribute11,
                    rec_po_insert_lines.Global_Attribute12,
                    rec_po_insert_lines.Global_Attribute13,
                    rec_po_insert_lines.Global_Attribute14,
                    rec_po_insert_lines.Global_Attribute15,
                    rec_po_insert_lines.Global_Attribute16,
                    rec_po_insert_lines.Global_Attribute17,
                    rec_po_insert_lines.Global_Attribute18,
                    rec_po_insert_lines.Global_Attribute19,
                    rec_po_insert_lines.Global_Attribute20,
                    rec_po_insert_lines.Expiration_Date,
                    rec_po_insert_lines.Base_Uom,
                    rec_po_insert_lines.Base_Qty,
                    rec_po_insert_lines.Secondary_Uom,
                    rec_po_insert_lines.Secondary_Qty,
                    rec_po_insert_lines.Qc_Grade,
                    rec_po_insert_lines.oke_contract_header_id,
                    rec_po_insert_lines.oke_contract_version_id,
                    rec_po_insert_lines.Secondary_Unit_Of_Measure,
                    rec_po_insert_lines.Secondary_Quantity,
                    rec_po_insert_lines.Preferred_Grade,
                    rec_po_insert_lines.contract_id,
                    rec_po_insert_lines.job_id,
                    rec_po_insert_lines.contractor_first_name,
                    rec_po_insert_lines.contractor_last_name,
                    NULL, --rec_po_insert_lines.assignment_start_date             ,
                    NULL, --rec_po_insert_lines.amount_db                         ,
                    rec_po_insert_lines.order_type_lookup_code,
                    rec_po_insert_lines.purchase_basis,
                    rec_po_insert_lines.matching_basis,
                    rec_po_insert_lines.Base_Unit_Price,
                    rec_po_insert_lines.manual_price_change_flag,
                    NULL, --rec_po_insert_lines.consigned_from_supplier_flag  ,
                    rec_po_insert_lines.org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error in insert po line API'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            BEGIN
                SELECT shipment_num
                  INTO ln_shipment_num
                  FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
                 WHERE     1 = 1
                       AND pla.line_num = ln_line_num
                       AND pha.segment1 = pv_po_number
                       AND pla.po_line_id = plla.po_line_id
                       AND pha.po_header_id = pla.po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error in while getting shipment number in insert po line'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            BEGIN                                                           --
                IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                THEN
                    update_shipment_line (pn_err_code, pv_err_message, 'FROM INSERT', pn_user_id, pn_line_num, ln_line_num, pn_shipment_num, TO_NUMBER (ln_shipment_num), pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                          , pd_new_promised_date);
                END IF;

                IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                THEN
                    insert_distribution_line (pn_err_code, pv_err_message, pn_user_id, TO_NUMBER (pn_line_num), TO_NUMBER (pn_shipment_num), TO_NUMBER (pn_distrb_num), TO_NUMBER (ln_line_num), TO_NUMBER (ln_shipment_num), pv_po_number
                                              , pn_quantity);

                    -- Update PO Line is used to just make the PO into Requires Reapproval
                    -- In 12.0.6, when we are using Insert API, the status of PO is in Requires Reapproval status, where as in 12.2.3 it is in Approved Status
                    -- However, the status is in Shipments table is not in approved status, so need to Approve in correct status
                    -- We want't PO to be in Requires Reapproval status and we can approve using PO Approval program. So, invoking below procedure

                    update_po_line (pn_err_code,
                                    pv_err_message,
                                    pn_user_id,
                                    TO_NUMBER (ln_line_num),
                                    TO_NUMBER (ln_shipment_num),
                                    pv_po_number,
                                    pn_quantity,
                                    pn_unit_price,
                                    pd_new_promised_date);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error in insert po line while calling update and distribution procedures'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            xn_line_num       := ln_line_num; --Assiging new PO line num & Shipment num to the out paramters
            xn_shipment_num   := ln_shipment_num;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                'Error in insert po line' || '-' || SUBSTR (SQLERRM, 1, 900);
    END insert_po_line;

    /*
    insert_distribution_line procedure is used to insert distribution line for the newly inserted line using private API, invoked from
    insert_po_line procedure
    */
    PROCEDURE insert_distribution_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pn_new_line_num NUMBER, pn_new_shipment_num NUMBER, pv_po_number VARCHAR2
                                        , pn_quantity NUMBER)
    IS
        lv_rowid              VARCHAR2 (4000);
        ln_dist_id            NUMBER;
        lv_line_id            NUMBER;
        lv_line_location_id   NUMBER;

        CURSOR cur_po_distrb_lines IS
            SELECT pda.ROWID, pda.*
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla,
                   apps.po_distributions_all pda
             WHERE     1 = 1
                   AND pda.distribution_num = pn_distrb_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pla.line_num = pn_line_num
                   AND pha.segment1 = pv_po_number
                   AND pda.po_line_id = pla.po_line_id
                   AND pda.po_header_id = pha.po_header_id
                   AND plla.po_line_id = pla.po_line_id
                   AND pla.po_header_id = pha.po_header_id;
    BEGIN
        FOR rec_po_distrb_lines IN cur_po_distrb_lines
        LOOP
            BEGIN
                SELECT apps.po_distributions_s.NEXTVAL
                  INTO ln_dist_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error while getting distribution id from sequence PO_DISTRIBUTIONS_S'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            BEGIN
                SELECT pla.po_line_id, plla.line_location_id
                  INTO lv_line_id, lv_line_location_id
                  FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
                 WHERE     1 = 1
                       AND pla.line_num = pn_new_line_num
                       AND plla.shipment_num = pn_new_shipment_num
                       AND pha.segment1 = pv_po_number
                       AND pla.po_line_id = plla.po_line_id
                       AND pha.po_header_id = pla.po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error while getting distribution id, line id, line location id in insert distribution line'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            --dbms_output.put_line('lv line id:'||lv_line_id);
            --dbms_output.put_line('lv line location id:'||lv_line_location_id);

            apps.po_distributions_pkg1.insert_row (
                lv_rowid,                                            --X_Rowid
                ln_dist_id,                             --X_Po_Distribution_Id
                SYSDATE,                                  --X_Last_Update_Date
                pn_user_id,                                --X_Last_Updated_By
                rec_po_distrb_lines.po_header_id,
                lv_line_id,
                lv_line_location_id,
                rec_po_distrb_lines.set_of_books_id,
                rec_po_distrb_lines.code_combination_id,
                pn_quantity,                     --X_Quantity_Ordered        ,
                pn_user_id,                             --X_Last_Update_Logi ,
                SYSDATE,                                     --X_Creation_Da ,
                pn_user_id,                             --X_Created_By       ,
                rec_po_distrb_lines.po_release_id,
                --Commented START as part of Incident INC0306175 by Ravi
                --rec_po_distrb_lines.quantity_delivered,
                --rec_po_distrb_lines.quantity_billed,
                --Commented START as part of Incident INC0306175
                --Added START as part of Incident INC0306175
                NULL,                                    -- quantity_delivered
                NULL,                                       -- quantity_billed
                --Added START as part of Incident INC0306175
                NULL, --rec_po_distrb_lines.quantity_cancelled, Commented by Ravi for Incident INC0306175
                rec_po_distrb_lines.req_header_reference_num,
                rec_po_distrb_lines.req_line_reference_num,
                rec_po_distrb_lines.req_distribution_id,
                rec_po_distrb_lines.deliver_to_location_id,
                rec_po_distrb_lines.deliver_to_person_id,
                SYSDATE,                                     --X_Rate_Date   ,
                rec_po_distrb_lines.rate,
                NULL, --rec_po_distrb_lines.amount_billed,Commented  Ravi for Incident INC0306175
                rec_po_distrb_lines.accrued_flag,
                rec_po_distrb_lines.encumbered_flag,
                rec_po_distrb_lines.encumbered_amount,
                rec_po_distrb_lines.unencumbered_quantity,
                rec_po_distrb_lines.unencumbered_amount,
                rec_po_distrb_lines.failed_funds_lookup_code,
                rec_po_distrb_lines.gl_encumbered_date,
                rec_po_distrb_lines.gl_encumbered_period_name,
                rec_po_distrb_lines.gl_cancelled_date,
                rec_po_distrb_lines.destination_type_code,
                rec_po_distrb_lines.destination_organization_id,
                rec_po_distrb_lines.destination_subinventory,
                rec_po_distrb_lines.attribute_category,
                rec_po_distrb_lines.attribute1,
                rec_po_distrb_lines.attribute2,
                rec_po_distrb_lines.attribute3,
                rec_po_distrb_lines.attribute4,
                rec_po_distrb_lines.attribute5,
                rec_po_distrb_lines.attribute6,
                rec_po_distrb_lines.attribute7,
                rec_po_distrb_lines.attribute8,
                rec_po_distrb_lines.attribute9,
                rec_po_distrb_lines.attribute10,
                rec_po_distrb_lines.attribute11,
                rec_po_distrb_lines.attribute12,
                rec_po_distrb_lines.attribute13,
                rec_po_distrb_lines.attribute14,
                rec_po_distrb_lines.attribute15,
                rec_po_distrb_lines.wip_entity_id,
                rec_po_distrb_lines.wip_operation_seq_num,
                rec_po_distrb_lines.wip_resource_seq_num,
                rec_po_distrb_lines.wip_repetitive_schedule_id,
                rec_po_distrb_lines.wip_line_id,
                rec_po_distrb_lines.bom_resource_id,
                rec_po_distrb_lines.budget_account_id,
                rec_po_distrb_lines.accrual_account_id,
                rec_po_distrb_lines.variance_account_id,
                --< Shared Proc FPJ Start >    ,
                rec_po_distrb_lines.dest_charge_account_id,
                rec_po_distrb_lines.dest_variance_account_id,
                --< Shared Proc FPJ End >      ,
                rec_po_distrb_lines.prevent_encumbrance_flag,
                rec_po_distrb_lines.ussgl_transaction_code,
                rec_po_distrb_lines.government_context,
                rec_po_distrb_lines.destination_context,
                rec_po_distrb_lines.distribution_num,
                rec_po_distrb_lines.source_distribution_id,
                rec_po_distrb_lines.project_id,
                rec_po_distrb_lines.task_id,
                rec_po_distrb_lines.expenditure_type,
                rec_po_distrb_lines.project_accounting_context,
                rec_po_distrb_lines.expenditure_organization_id,
                rec_po_distrb_lines.gl_closed_date,
                rec_po_distrb_lines.accrue_on_receipt_flag,
                rec_po_distrb_lines.expenditure_item_date,
                rec_po_distrb_lines.end_item_unit_number,
                rec_po_distrb_lines.recovery_rate,
                rec_po_distrb_lines.recoverable_tax,
                rec_po_distrb_lines.nonrecoverable_tax,
                rec_po_distrb_lines.tax_recovery_override_flag,
                rec_po_distrb_lines.award_id,                     --NUMBER D ,
                --togeorge 09/28/2000         ,
                --added  oke variables        ,
                rec_po_distrb_lines.oke_contract_line_id,
                rec_po_distrb_lines.oke_contract_deliverable_id,
                rec_po_distrb_lines.amount_ordered,
                rec_po_distrb_lines.distribution_type,
                rec_po_distrb_lines.amount_to_encumber,
                rec_po_distrb_lines.org_id);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in insert distribution line'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END insert_distribution_line;

    /*
   update_asn_line procedure is used to update ASN information of PO, if Packing manifest is approved, invoked from
   process_normal_po procedure
   */
    PROCEDURE update_asn_line (pn_err_code            OUT NUMBER,
                               pv_err_message         OUT VARCHAR2,
                               pn_user_id                 NUMBER,
                               pn_line_num                NUMBER,
                               pn_shipment_num            NUMBER,
                               pv_po_number               VARCHAR2,
                               pn_quantity                NUMBER,
                               pn_unit_price              NUMBER,
                               pd_new_promised_date       DATE)
    IS
        ln_asn_count   NUMBER;


        CURSOR cur_po_line_locs IS
            SELECT plla.*
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND pla.line_num = pn_line_num
                   AND plla.shipment_num = pn_shipment_num
                   AND pha.segment1 = pv_po_number
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
    BEGIN
        FOR rec_po_line_locs IN cur_po_line_locs
        LOOP
            SELECT COUNT (1)
              INTO ln_asn_count
              FROM apps.do_items
             WHERE     1 = 1
                   AND atr_number IS NULL
                   AND order_id = rec_po_line_locs.po_header_id
                   AND order_line_id = rec_po_line_locs.po_line_id
                   AND line_location_id = rec_po_line_locs.line_location_id;


            IF (ln_asn_count > 0)
            THEN
                BEGIN
                    UPDATE apps.do_items
                       SET quantity = pn_quantity, entered_quantity = pn_quantity, price = pn_unit_price,
                           promised_date = pd_new_promised_date, last_updated_by = pn_user_id, last_update_date = SYSDATE
                     WHERE     order_id = rec_po_line_locs.po_header_id
                           AND order_line_id = rec_po_line_locs.po_line_id
                           AND line_location_id =
                               rec_po_line_locs.line_location_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error in while updating asn line'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in update asn line procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_asn_line;

    /*
    check_order function checks whether the PO is a dropship PO/Normal PO, XDOCK PO
    */
    FUNCTION check_order (pv_po_number VARCHAR2, pn_line_num NUMBER)
        RETURN NUMBER
    IS
        ln_po_header_id   NUMBER;
        ln_po_line_id     NUMBER;
        ln_order_cnt      NUMBER;
        lv_order_type     VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT pla.po_header_id, pla.po_line_id, pha.attribute10
              INTO ln_po_header_id, ln_po_line_id, lv_order_type
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     1 = 1
                   AND pla.line_num = pn_line_num
                   AND pha.segment1 = pv_po_number
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 0;
        END;


        IF ln_po_header_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_order_cnt
              FROM apps.oe_drop_ship_sources ods
             WHERE     po_header_id = ln_po_header_id
                   AND po_line_id = ln_po_line_id;
        END IF;

        IF (ln_order_cnt > 0)
        THEN
            ln_order_cnt   := 1;                                 --Dropship PO
                               -- If ln_order_cnt = 0, then it is Normal Order
        END IF;


        IF (lv_order_type = 'XDOCK')                      -- Special VAS Order
        THEN
            ln_order_cnt   := 2;
        END IF;

        RETURN ln_order_cnt;
    END check_order;

    /*
    Below procedure process if the PO is a normal PO, update/insert PO line depends on the Split flag
    */
    PROCEDURE process_normal_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                 , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2)
    IS
        ln_line_num       NUMBER;
        ln_shipment_num   NUMBER;
    BEGIN
        --validate Spilt Flag
        IF UPPER (pv_split_flag) = 'FALSE'               -- Update the PO line
        THEN
            -- DBMS_OUTPUT.put_line ('In  process normal PO Update PO Line');

            update_po_line (pn_err_code, pv_err_message, pn_user_id,
                            pn_line_num, pn_shipment_num, pv_po_number,
                            pn_quantity, pn_unit_price, pd_new_promised_date);

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                --DBMS_OUTPUT.put_line ('In Process normal Update Shipment Line');

                update_shipment_line (pn_err_code,     -- Update Shipment line
                                                   pv_err_message, 'FROM UPDATE', pn_user_id, NULL, -- Original Line number not required
                                                                                                    pn_line_num, NULL, -- Original Shipment Line number not required
                                                                                                                       pn_shipment_num, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                      , pd_new_promised_date);
            END IF;

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_asn_line (pn_err_code, -- Update ASN line if Packing Manifest is Approved
                                 pv_err_message,
                                 pn_user_id,
                                 pn_line_num,
                                 pn_shipment_num,
                                 pv_po_number,
                                 pn_quantity,
                                 pn_unit_price,
                                 pd_new_promised_date);
            END IF;
        ELSIF UPPER (pv_split_flag) = 'TRUE'                                --
        THEN
            IF (UPPER (pv_original_line_flag) = 'TRUE')
            THEN
                update_po_line (pn_err_code, -- Update one of the split PO line
                                pv_err_message,
                                pn_user_id,
                                pn_line_num,
                                pn_shipment_num,
                                pv_po_number,
                                pn_quantity,
                                pn_unit_price,
                                pd_new_promised_date);

                IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                THEN
                    update_shipment_line (pn_err_code, -- Update one of the split Shipment line
                                                       pv_err_message, 'FROM UPDATE', pn_user_id, NULL, pn_line_num, NULL, pn_shipment_num, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                          , pd_new_promised_date);
                END IF;

                IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                THEN
                    update_asn_line (pn_err_code, -- Update ASN line if Packing Manifest is Approved
                                     pv_err_message,
                                     pn_user_id,
                                     pn_line_num,
                                     pn_shipment_num,
                                     pv_po_number,
                                     pn_quantity,
                                     pn_unit_price,
                                     pd_new_promised_date);
                END IF;
            ELSE
                insert_po_line (pn_err_code,          -- Insert Split PO lines
                                pv_err_message,
                                pn_user_id,
                                pn_line_num,
                                pn_shipment_num,
                                pn_distrb_num,
                                pv_po_number,
                                pv_shipmethod,
                                pn_quantity,
                                pd_exfactory_date,
                                pn_unit_price,
                                pd_new_promised_date,
                                pv_freight_pay_party,
                                ln_line_num,
                                ln_shipment_num);
            -- DBMS_OUTPUT.put_line ('In SPLIT');

            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in process normal PO procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END process_normal_po;

    /*
    Below procedure process if the PO is a dropship PO, update/insert both Sales order and PO line depends on the Split flag
    */
    PROCEDURE process_dropship_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                   , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2)
    IS
        ln_so_header_id       NUMBER;
        ln_so_line_id         NUMBER;
        ln_so_new_line_id     NUMBER;
        ln_new_line_num       NUMBER;
        ln_new_shipment_num   NUMBER;
        ln_header_id          NUMBER;
        ln_line_id            NUMBER;
        ln_location_id        NUMBER;
        ln_agent_id           NUMBER;
        ln_so_hold_count      NUMBER;
    BEGIN
        BEGIN
            SELECT ods.header_id, ods.line_id
              INTO ln_so_header_id, ln_so_line_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.oe_drop_ship_sources ods
             WHERE     1 = 1
                   AND pla.line_num = pn_line_num
                   AND segment1 = pv_po_number
                   AND ods.po_line_id = pla.po_line_id
                   AND ods.po_header_id = pha.po_header_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting SO information in Process dropship PO procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        IF (UPPER (pv_split_flag) = 'FALSE')
        THEN
            salesorder_line (pn_err_code,
                             pv_err_message,
                             pn_user_id,
                             ln_so_header_id,
                             ln_so_line_id,
                             pn_quantity,
                             pd_new_promised_date,
                             'UPDATE',
                             ln_so_new_line_id);

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_drop_ship_po_line (pn_err_code, -- Update Unit price on Dropship PO line
                                                       pv_err_message, pn_user_id, pn_line_num, pn_line_num, pn_shipment_num
                                          , pv_po_number, pn_unit_price);
            END IF;


            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_shipment_line (pn_err_code,     -- Update Shipment line
                                                   pv_err_message, 'FROM UPDATE', pn_user_id, NULL, -- Original Line number not required
                                                                                                    pn_line_num, NULL, -- Original Shipment Line number not required
                                                                                                                       pn_shipment_num, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                      , pd_new_promised_date);
            END IF;

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_asn_line (pn_err_code, -- Update ASN line if Packing Manifest is Approved
                                 pv_err_message,
                                 pn_user_id,
                                 pn_line_num,
                                 pn_shipment_num,
                                 pv_po_number,
                                 pn_quantity,
                                 pn_unit_price,
                                 pd_new_promised_date);
            END IF;

            ln_so_hold_count   := get_so_hold_status (ln_so_header_id); -- After SO line is Updated, we are checking if Hold is applied, if so release it.

            IF (ln_so_hold_count > 0)
            THEN
                release_so_hold (pn_err_code, pv_err_message, ln_so_header_id
                                 , pn_user_id);
            END IF;
        ELSIF UPPER (pv_split_flag) = 'TRUE'                                --
        THEN
            ln_so_hold_count   := get_so_hold_status (ln_so_header_id);

            IF (ln_so_hold_count = 0)
            THEN
                IF (UPPER (pv_original_line_flag) = 'TRUE')
                THEN
                    salesorder_line (pn_err_code,
                                     pv_err_message,
                                     pn_user_id,
                                     ln_so_header_id,
                                     ln_so_line_id,
                                     pn_quantity,
                                     pd_new_promised_date,
                                     'UPDATE',
                                     ln_so_new_line_id);

                    IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                    THEN
                        update_drop_ship_po_line (pn_err_code, -- Update Unit Price on Dropship PO line
                                                  pv_err_message,
                                                  pn_user_id,
                                                  pn_line_num,
                                                  pn_line_num,
                                                  pn_shipment_num,
                                                  pv_po_number,
                                                  pn_unit_price);
                    END IF;



                    IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                    THEN
                        update_shipment_line (pn_err_code, -- Update Shipment line
                                                           pv_err_message, 'FROM UPDATE', pn_user_id, NULL, -- Original Line number not required
                                                                                                            pn_line_num, NULL, -- Original Shipment Line number not required
                                                                                                                               pn_shipment_num, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                              , pd_new_promised_date);
                    END IF;

                    IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                    THEN
                        update_asn_line (pn_err_code, -- Update ASN line if Packing Manifest is Approved
                                         pv_err_message,
                                         pn_user_id,
                                         pn_line_num,
                                         pn_shipment_num,
                                         pv_po_number,
                                         pn_quantity,
                                         pn_unit_price,
                                         pd_new_promised_date);
                    END IF;

                    ln_so_hold_count   :=
                        get_so_hold_status (ln_so_header_id); -- After SO line is Updated, we are checking if Hold is applied, if so release it.

                    IF (ln_so_hold_count > 0)
                    THEN
                        release_so_hold (pn_err_code, pv_err_message, ln_so_header_id
                                         , pn_user_id);
                    END IF;
                ELSIF (UPPER (pv_original_line_flag) = 'FALSE')
                THEN
                    salesorder_line (pn_err_code,
                                     pv_err_message,
                                     pn_user_id,
                                     ln_so_header_id,
                                     ln_so_line_id,
                                     pn_quantity,
                                     pd_new_promised_date,
                                     'INSERT',
                                     ln_so_new_line_id);

                    -- We cannot directly run the Purchase release once the SO line is booked, we need to wait till the Workflow program run.
                    --dbms_lock.sleep(180); -- Hold for 3 minutes to Workflow background process start off as this Program is scheduled every 2mins

                    ln_so_hold_count   :=
                        get_so_hold_status (ln_so_header_id); -- After new SO line inserted, we are checking if Hold is applied, if so release it.

                    IF (ln_so_hold_count > 0)
                    THEN
                        release_so_hold (pn_err_code, pv_err_message, ln_so_header_id
                                         , pn_user_id);
                    END IF;

                    IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                    THEN
                        ---- WAIT FOR THE 3 Programs to Complete
                        BEGIN
                            run_programs (pn_err_code, pv_err_message, pn_user_id, ln_so_new_line_id, pv_po_number, pn_line_num
                                          , ln_so_new_line_id, pn_quantity);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pn_err_code   := SQLCODE;
                                pv_err_message   :=
                                       'Error in run programs procedure'
                                    || '-'
                                    || SUBSTR (SQLERRM, 1, 900);
                        END;

                        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                        THEN
                            autocreate_po_from_req (pn_err_code, pv_err_message, pn_user_id, ln_so_new_line_id, pv_po_number, pn_line_num
                                                    , ln_new_line_num);
                        END IF;

                        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                        THEN
                            update_drop_ship_po_line (pn_err_code, -- Update Unit Price on Dropship PO line
                                                      pv_err_message,
                                                      pn_user_id,
                                                      pn_line_num,
                                                      ln_new_line_num,
                                                      pn_shipment_num,
                                                      pv_po_number,
                                                      pn_unit_price);
                        END IF;

                        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
                        THEN
                            update_shipment_line (pn_err_code, pv_err_message, 'FROM INSERT', pn_user_id, pn_line_num, -- Original Line number
                                                                                                                       ln_new_line_num, pn_shipment_num, -- Original Shipment Line number
                                                                                                                                                         1, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                                  , pd_new_promised_date);
                        END IF;
                    -- Approve PO
                    --Change: 2.6
                    --Commenting below code as we are asking SOA to call Approve API at end of the POC file

                    --                        IF(
                    --                           pn_err_code IS NULL AND
                    --                           pv_err_message IS NULL
                    --                           )
                    --                        THEN
                    --
                    --                           approve_po (  pn_err_code,
                    --                                          pv_err_message,
                    --                                          pv_po_number
                    --                                       );
                    --                        END IF;

                    --                      BEGIN
                    --
                    --
                    --                            SELECT pha.po_header_id, pha.agent_id
                    --                              INTO ln_header_id, ln_agent_id
                    --                              FROM apps.po_headers_all pha
                    --                             WHERE 1 = 1
                    --                               AND pha.segment1 = pv_po_number;
                    --
                    --                      EXCEPTION
                    --                      WHEN OTHERS
                    --                      THEN
                    --                          pn_err_code  := SQLCODE;
                    --                          pv_err_message := 'Error while getting new PO line id and line location id in Process Dropship PO procedure'||'-'||SUBSTR(SQLERRM,1,900);
                    --
                    --                      END;
                    --
                    --                      BEGIN
                    --
                    --                            APPS.PO_REQAPPROVAL_INIT1.Start_WF_Process
                    --                                           (ItemType => 'POAPPRV'
                    --                                           ,ItemKey => 100
                    --                                           ,WorkflowProcess => 'POAPPRV_TOP'
                    --                                           ,ActionOriginatedFrom => 'PO_FORM'
                    --                                           ,DocumentID => ln_header_id
                    --                                           ,DocumentNumber => pv_po_number
                    --                                           ,PreparerID => ln_agent_id
                    --                                           ,DocumentTypeCode => 'PO'
                    --                                            ,DocumentSubtype => 'STANDARD'
                    --                                            ,SubmitterAction => 'APPROVE'--''INCOMPLETE'
                    --                                            ,forwardToID => NULL--null-- EMPLOYEEID
                    --                                            ,forwardFromID => ln_agent_id
                    --                                            ,DefaultApprovalPathID => null
                    --                                            ,Note => null
                    --                                            ,printFlag => 'N');

                    --                      EXCEPTION
                    --                      WHEN OTHERS
                    --                      THEN
                    --
                    --                            pn_err_code  := SQLCODE;
                    --                            pv_err_message := 'Error in approval work flow in process dropship PO procedure'||'-'||SUBSTR(SQLERRM,1,900);
                    --
                    --                      END;

                    END IF;
                END IF;
            ELSE
                pn_err_code   := -1;
                pv_err_message   :=
                    'Associated Sales Order has Credit check hold applied, please release the hold and retry.';
            END IF;
        END IF;
    END process_dropship_po;

    /*
    Below procedure update/insert SO line using Standard API based on the split flag
    */
    PROCEDURE salesorder_line (pn_err_code       OUT NUMBER,
                               pv_err_message    OUT VARCHAR2,
                               pn_user_id            NUMBER,
                               pn_header_id          NUMBER,
                               pn_line_id            NUMBER,
                               pn_quantity           NUMBER,
                               pd_request_date       DATE,
                               pv_so_source          VARCHAR2,
                               xn_so_line_id     OUT NUMBER)
    IS
        l_header_rec                   apps.oe_order_pub.header_rec_type;
        l_line_tbl                     apps.oe_order_pub.line_tbl_type;
        l_action_request_tbl           apps.oe_order_pub.request_tbl_type;
        l_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               apps.oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  apps.oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := apps.fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := apps.fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        x_header_rec                   apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_old_header_rec               apps.oe_order_pub.header_rec_type
                                           := apps.oe_order_pub.g_miss_header_rec;
        p_header_val_rec               apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           apps.oe_order_pub.header_val_rec_type
                                           := apps.oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           apps.oe_order_pub.header_adj_tbl_type
                                           := apps.oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       apps.oe_order_pub.header_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     apps.oe_order_pub.header_price_att_tbl_type
            := apps.oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       apps.oe_order_pub.header_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     apps.oe_order_pub.header_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       apps.oe_order_pub.header_scredit_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   apps.oe_order_pub.header_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_header_scredit_val_tbl;
        x_line_tbl                     apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 apps.oe_order_pub.line_tbl_type
            := apps.oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             apps.oe_order_pub.line_val_tbl_type
            := apps.oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             apps.oe_order_pub.line_adj_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         apps.oe_order_pub.line_adj_val_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       apps.oe_order_pub.line_price_att_tbl_type
            := apps.oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         apps.oe_order_pub.line_adj_att_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       apps.oe_order_pub.line_adj_assoc_tbl_type
            := apps.oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         apps.oe_order_pub.line_scredit_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     apps.oe_order_pub.line_scredit_val_tbl_type
            := apps.oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           apps.oe_order_pub.lot_serial_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       apps.oe_order_pub.lot_serial_val_tbl_type
            := apps.oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           apps.oe_order_pub.request_tbl_type
            := apps.oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               apps.oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               apps.oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           apps.oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         apps.oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           apps.oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         apps.oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           apps.oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       apps.oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 apps.oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 apps.oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             apps.oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           apps.oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             apps.oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           apps.oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             apps.oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         apps.oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               apps.oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           apps.oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           apps.oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_msg_index_out                NUMBER (10);
        l_line_tbl_index               NUMBER;

        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
        ln_org_id                      NUMBER;
        ln_item_id                     NUMBER;
        ln_ship_from_org_id            NUMBER;
        lv_subinventory                VARCHAR2 (1000);
        ln_attribute1                  VARCHAR2 (1000);
        ld_promise_date                DATE;
        ld_request_date                DATE;
        ln_line_type_id                NUMBER;
        ln_salesrep_id                 NUMBER;
    BEGIN
        /* DBMS_OUTPUT.put_line ('In Update SO Line:UserId'||pn_user_id     );
         DBMS_OUTPUT.put_line ('In Update SO Line:pn_header_id' || pn_header_id   );
         DBMS_OUTPUT.put_line ('In Update SO Line:pn_line_id  '  ||pn_line_id     );
         DBMS_OUTPUT.put_line ('In Update SO Line:pn_quantity '  ||pn_quantity    );
          DBMS_OUTPUT.put_line ('In Update SO Line:pd_request_date'|| pd_request_date);
          DBMS_OUTPUT.put_line ('In Update SO Line:pv_so_source' ||pv_so_source   );
          --DBMS_OUTPUT.put_line ('In Update SO Line:' xn_so_line_id  );*/



        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.oe_order_headers_all
             WHERE header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Sales order Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name_so     --'MO: Operating Unit'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_so || '%' --'Deckers Order Management User%'
                   AND fpov.profile_option_value = TO_CHAR (ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id in SO procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;



        --dbms_output.ENABLE(1000000);


        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        -- pass in user_id, responsibility_id, and application_id
        apps.oe_msg_pub.initialize;
        apps.oe_debug_pub.initialize;
        apps.mo_global.Init ('ONT');                       -- Required for R12
        apps.mo_global.Set_org_context (ln_org_id, NULL, 'ONT');
        apps.fnd_global.Set_nls_context ('AMERICAN');
        apps.mo_global.Set_policy_context ('S', ln_org_id); -- Required for R12

        /* dbms_output.ENABLE(1000000);
         apps.fnd_global.Apps_initialize(1037, 50849, 660);
         -- pass in user_id, responsibility_id, and application_id
         apps.oe_msg_pub.initialize;
         apps.oe_debug_pub.initialize;
         apps.mo_global.Init ('ONT'); -- Required for R12
         apps.mo_global.Set_org_context (94, NULL, 'ONT');
         apps.fnd_global.Set_nls_context ('AMERICAN');
         apps.mo_global.Set_policy_context ('S', 94); -- Required for R12*/



        BEGIN
            SELECT inventory_item_id, ship_from_org_id, subinventory
              INTO ln_item_id, ln_ship_from_org_id, lv_subinventory
              FROM apps.oe_order_lines_all
             WHERE header_id = pn_header_id AND line_id = pn_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting item id, ship from org id, sub inventory in SO procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT promise_date, request_date, line_type_id,
                   salesrep_id, attribute1
              INTO ld_promise_date, ld_request_date, ln_line_type_id, ln_salesrep_id,
                                  ln_attribute1
              FROM apps.oe_order_lines_all
             WHERE header_id = pn_header_id AND line_id = pn_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Promise date, Request date in SO procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;


        l_line_tbl_index                := 1;
        -- Changed attributes
        l_line_tbl (l_line_tbl_index)   := apps.oe_order_pub.G_MISS_LINE_REC;

        IF pd_request_date IS NOT NULL
        THEN
            ld_request_date   := pd_request_date;
        END IF;



        IF (UPPER (pv_so_source) = 'UPDATE')
        THEN
            l_line_tbl (l_line_tbl_index).ordered_quantity   := pn_quantity;
            l_line_tbl (l_line_tbl_index).line_id            := pn_line_id;
            l_line_tbl (l_line_tbl_index).change_reason      := 'SYSTEM';
            -- l_line_tbl(l_line_tbl_index).promise_date := pd_request_date;
            l_line_tbl (l_line_tbl_index).request_date       :=
                ld_request_date;
            --L_line_tbl(l_line_tbl_index).schedule_ship_date := ld_request_date;
            --L_line_tbl(l_line_tbl_index).schedule_status_code := 'SCHEDULED';
            L_line_tbl (l_line_tbl_index).schedule_action_code   :=
                apps.OE_GLOBALS.G_SCHEDULE_LINE;
            l_line_tbl (l_line_tbl_index).operation          :=
                apps.OE_GLOBALS.G_OPR_UPDATE;
        ELSIF (UPPER (pv_so_source) = 'INSERT')
        THEN
            --Mandatory fields like qty, inventory item id are to be passed
            L_line_tbl (l_line_tbl_index).header_id           := pn_header_id;
            L_line_tbl (l_line_tbl_index).ordered_quantity    := pn_quantity;
            L_line_tbl (l_line_tbl_index).inventory_item_id   := ln_item_id;
            L_line_tbl (l_line_tbl_index).ship_from_org_id    :=
                ln_ship_from_org_id;
            L_line_tbl (l_line_tbl_index).subinventory        :=
                lv_subinventory;
            L_line_tbl (l_line_tbl_index).promise_date        :=
                ld_promise_date;
            L_line_tbl (l_line_tbl_index).request_date        :=
                ld_request_date;
            --L_line_tbl(l_line_tbl_index).schedule_ship_date := ld_request_date;
            L_line_tbl (l_line_tbl_index).salesrep_id         :=
                ln_salesrep_id;
            L_line_tbl (l_line_tbl_index).schedule_status_code   :=
                'SCHEDULED';
            L_line_tbl (l_line_tbl_index).attribute1          :=
                ln_attribute1;
            L_line_tbl (l_line_tbl_index).operation           :=
                apps.oe_globals.g_opr_create;
            L_line_tbl (l_line_tbl_index).line_type_id        :=
                ln_line_type_id;
            L_line_tbl (l_line_tbl_index).source_type_code    :=
                'EXTERNAL';
        END IF;



        -- CALL TO PROCESS ORDER
        apps.oe_order_pub.Process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => apps.fnd_api.g_false,
            p_return_values            => apps.fnd_api.g_false,
            p_action_commit            => apps.fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl-- OUT PARAMETERS
                                                              ,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => x_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => x_action_request_tbl);

        --dbms_output.put_line('OM Debug file: ' ||oe_debug_pub.G_DIR||'/'||oe_debug_pub.G_FILE);
        -- Retrieve messages
        --dbms_output.Put_line('Line Id: ' ||x_line_tbl(l_line_tbl_index).line_id);

        xn_so_line_id                   :=
            x_line_tbl (l_line_tbl_index).line_id;

        FOR i IN 1 .. l_msg_count
        LOOP
            apps.oe_msg_pub.Get (p_msg_index => i, p_encoded => apps.fnd_api.g_false, p_data => l_msg_data
                                 , p_msg_index_out => l_msg_index_out);
        -- dbms_output.Put_line('message is: ' || l_msg_data);
        --dbms_output.Put_line('message index is: ' || l_msg_index_out);
        END LOOP;

        --Check the return status
        IF l_return_status = apps.fnd_api.g_ret_sts_success
        THEN
            pn_err_code   := NULL;
        ELSE
            pn_err_code   := 1;
            pv_err_message   :=
                   'Error while processing '
                || pv_so_source
                || 'at SO line level in Sales order Procedure'
                || l_msg_data
                || 'index: '
                || l_msg_index_out;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error while processing '
                || pv_so_source
                || 'at SO line level in Sales order Procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END salesorder_line;

    /*
    Below procedure runs Purchase Release, Requisition Import programs, this is invoked only in the case of Dropship PO
    */
    PROCEDURE run_programs (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_id NUMBER, pv_po_number IN VARCHAR2, pn_line_num NUMBER
                            , pn_so_new_line_id NUMBER, pn_quantity NUMBER)
    IS
        --Cursor to get the distinct batch_id's
        CURSOR cur_batch_id (ln_item_id IN NUMBER)
        IS
            SELECT pria.batch_id, pria.org_id
              FROM apps.po_requisitions_interface_all pria
             WHERE     pria.interface_source_code = 'ORDER ENTRY'
                   AND (pria.process_flag IS NULL OR pria.process_flag = 'PENDING')
                   AND item_id = ln_item_id
                   AND quantity = pn_quantity;



        ln_line_id           NUMBER;
        ln_location_id       NUMBER;
        ln_agent_id          NUMBER;
        ln_request_id        NUMBER;
        ln_org_id            NUMBER;

        lb_concreqcallstat   BOOLEAN := FALSE;

        lv_phasecode         VARCHAR2 (100) := NULL;
        lv_statuscode        VARCHAR2 (100) := NULL;
        lv_devphase          VARCHAR2 (100) := NULL;
        lv_devstatus         VARCHAR2 (100) := NULL;
        lv_returnmsg         VARCHAR2 (200) := NULL;

        lv_retcode           VARCHAR2 (4000);
        lv_reterror          VARCHAR2 (4000);
        lv_req_id            VARCHAR2 (4000);
        lv_request_id        VARCHAR2 (4000);
        ln_resp_id           NUMBER;
        ln_resp_appl_id      NUMBER;

        ln_item_id           NUMBER;
        ln_req_cnt           NUMBER;
        ln_order_number      NUMBER;
        lv_status_code       VARCHAR2 (100);

        econcreqsuberr       EXCEPTION;
    BEGIN
        -- Set Org Context
        BEGIN
            SELECT oola.org_id, ooha.order_number
              INTO ln_org_id, ln_order_number
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     1 = 1
                   AND line_id = pn_line_id
                   AND oola.header_id = ooha.header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Run Programs Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT item_id
              INTO ln_item_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     1 = 1
                   AND pla.line_num = pn_line_num
                   AND pha.segment1 = pv_po_number
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting item id Run programs Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            BEGIN
                SELECT frv.responsibility_id, frv.application_id resp_application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
                 WHERE     fpo.user_profile_option_name =
                           gv_mo_profile_option_name_so --'MO: Operating Unit'
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpov.level_value = frv.responsibility_id
                       AND frv.responsibility_name LIKE
                               gv_responsibility_name_so || '%' --'Deckers Order Management User%'
                       AND fpov.profile_option_value = TO_CHAR (ln_org_id)
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_resp_id        := gn_resp_id;
                    ln_resp_appl_id   := gn_resp_appl_id;
                    --lv_err_msg := SUBSTR(SQLERRM,1,900);
                    pn_err_code       := SQLCODE;
                    pv_err_message    :=
                           'Error in apps intialize while getting resp id in Run programs procedure'
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;

            apps.fnd_global.apps_initialize (pn_user_id,
                                             ln_resp_id,
                                             ln_resp_appl_id);
            apps.mo_global.init ('ONT');
            apps.mo_global.set_policy_context ('S', ln_org_id);
            apps.fnd_request.set_org_id (ln_org_id);

            --  DBMS_OUTPUT.put_line (' Start Time  ');

            --fnd_global.apps_initialize (<userid>, <applid>,<appluserid>);
            -- Run Workflow Background Process

            ln_request_id   := NULL;
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'FND',
                    program       => 'FNDWFBG',
                    description   => '',
                    start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS'),
                    sub_request   => FALSE,
                    argument1     => NULL,
                    argument2     => NULL,
                    argument3     => NULL,
                    argument4     => 'Y',
                    argument5     => 'N',
                    argument6     => NULL);

            COMMIT;


            --   DBMS_OUTPUT.PUT_LINE('ln_request_id: '||ln_request_id);

            IF ln_request_id = 0
            THEN
                RAISE econcreqsuberr;
            ELSE
                lv_req_id   := lv_req_id || ',' || ln_request_id;

                LOOP
                    lb_ConcReqCallStat   :=
                        apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                              5 -- wait 5 seconds between db checks
                                                               ,
                                                              0,
                                                              lv_phasecode,
                                                              lv_statuscode,
                                                              lv_devphase,
                                                              lv_devstatus,
                                                              lv_returnmsg);

                    EXIT WHEN lv_devphase = 'COMPLETE';
                END LOOP;
            END IF;

            LOOP
                ln_request_id   := NULL;
                ln_request_id   :=
                    apps.fnd_request.submit_request (
                        application   => 'ONT',
                        program       => 'OMPREL',
                        description   => '',
                        start_time    =>
                            TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS'),
                        sub_request   => FALSE,
                        argument1     => ln_org_id,
                        argument2     => ln_order_number,
                        argument3     => ln_order_number,
                        argument4     => NULL,
                        argument5     => NULL,
                        argument6     => NULL,
                        argument7     => NULL,
                        argument8     => NULL,
                        argument9     => NULL,
                        argument10    => NULL);
                COMMIT;

                IF ln_request_id = 0
                THEN
                    RAISE econcreqsuberr;
                ELSE
                    lv_req_id   := lv_req_id || ',' || ln_request_id;

                    LOOP
                        lb_ConcReqCallStat   :=
                            apps.fnd_concurrent.wait_for_request (
                                ln_request_id,
                                5          -- wait 5 seconds between db checks
                                 ,
                                0,
                                lv_phasecode,
                                lv_statuscode,
                                lv_devphase,
                                lv_devstatus,
                                lv_returnmsg);

                        EXIT WHEN lv_devphase = 'COMPLETE';
                    END LOOP;
                END IF;

                --  dbms_output.put_line('ln_request_id of Purchase Release:'||ln_request_id);
                SELECT flow_status_code
                  INTO lv_status_code
                  FROM apps.oe_order_lines_all
                 WHERE line_id = pn_so_new_line_id;

                EXIT WHEN lv_status_code = 'AWAITING_RECEIPT';
            END LOOP;
        EXCEPTION
            WHEN econcreqsuberr
            THEN
                pv_err_message   :=
                    SUBSTR (
                           'Error in conc.req submission in Run programs procedure: '
                        || SQLERRM,
                        1,
                        900);
                pn_err_code   := SQLCODE;
                RAISE;
            WHEN OTHERS
            THEN
                pv_err_message   :=
                    SUBSTR ('Error In Main Req Import: ' || SQLERRM, 1, 900);
                pn_err_code   := SQLCODE;
                RAISE;
        END;

        LOOP
            SELECT COUNT (1)
              INTO ln_req_cnt
              FROM apps.po_requisitions_interface_all pria
             WHERE     pria.interface_source_code = 'ORDER ENTRY'
                   AND (pria.process_flag IS NULL OR pria.process_flag = 'IN PROCESS')
                   AND item_id = ln_item_id
                   AND quantity = pn_quantity;

            EXIT WHEN ln_req_cnt > 0;
        END LOOP;

        DBMS_OUTPUT.put_line ('ln_req_cnt:' || ln_req_cnt);

        BEGIN
            FOR rec_batch_id IN cur_batch_id (ln_item_id)
            LOOP
                -- Set Org Context


                BEGIN
                    SELECT frv.responsibility_id, frv.application_id resp_application_id
                      INTO ln_resp_id, ln_resp_appl_id
                      FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
                     WHERE     fpo.user_profile_option_name =
                               gv_mo_profile_option_name --'MO: Security Profile'
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpov.level_value = frv.responsibility_id
                           AND frv.responsibility_name LIKE
                                   gv_responsibility_name || '%' --'Deckers Purchasing User%'
                           AND fpov.profile_option_value IN
                                   (SELECT security_profile_id
                                      FROM apps.per_security_organizations
                                     WHERE organization_id = ln_org_id)
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_resp_id        := gn_resp_id;
                        ln_resp_appl_id   := gn_resp_appl_id;
                        --lv_err_msg := SUBSTR(SQLERRM,1,900);
                        pn_err_code       := SQLCODE;
                        pv_err_message    :=
                               'Error in apps intialize while getting resp id in Run programs procedure'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;

                apps.fnd_global.apps_initialize (pn_user_id,
                                                 ln_resp_id,
                                                 ln_resp_appl_id);
                apps.mo_global.init ('PO');
                apps.mo_global.set_policy_context ('S', rec_batch_id.org_id);

                --  DBMS_OUTPUT.put_line (' Start Time  ');

                --fnd_global.apps_initialize (<userid>, <applid>,<appluserid>);


                apps.fnd_request.set_org_id (rec_batch_id.org_id);

                ln_request_id   := NULL;
                ln_request_id   :=
                    apps.fnd_request.submit_request (
                        application   => 'PO',
                        program       => 'REQIMPORT',
                        description   => '',
                        start_time    =>
                            TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS'),
                        sub_request   => FALSE,
                        argument1     => 'ORDER ENTRY',
                        argument2     => rec_batch_id.batch_id,
                        argument3     => 'VENDOR',
                        argument4     => NULL,
                        argument5     => 'N',
                        argument6     => 'N');
                COMMIT;

                IF ln_request_id = 0
                THEN
                    RAISE econcreqsuberr;
                ELSE
                    lv_req_id   := lv_req_id || ',' || ln_request_id;

                    LOOP
                        lb_ConcReqCallStat   :=
                            apps.fnd_concurrent.wait_for_request (
                                ln_request_id,
                                5          -- wait 5 seconds between db checks
                                 ,
                                0,
                                lv_phasecode,
                                lv_statuscode,
                                lv_devphase,
                                lv_devstatus,
                                lv_returnmsg);

                        EXIT WHEN lv_devphase = 'COMPLETE';
                    END LOOP;
                END IF;
            END LOOP;                           --End Loop For Batch Id Cursor
        --dbms_output.put_line('ln_request_id of Req Import:'||ln_request_id);


        EXCEPTION
            WHEN econcreqsuberr
            THEN
                pv_err_message   :=
                    SUBSTR (
                           'Error in conc.req submission in Run programs procedure: '
                        || SQLERRM,
                        1,
                        900);
                pn_err_code   := SQLCODE;
                RAISE;
            WHEN OTHERS
            THEN
                pv_err_message   :=
                    SUBSTR (
                           'Error In Main Req Import in Run programs procedure: '
                        || SQLERRM,
                        1,
                        900);
                pn_err_code   := SQLCODE;
                RAISE;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_message   :=
                SUBSTR ('Error in Run programs procedure: ' || SQLERRM,
                        1,
                        900);
            pn_err_code   := SQLCODE;
            RAISE;
    END run_programs;

    /*
    Below procedure autocreates new PO line to the exisiting PO from Requisition, this is invoked only if it is a dropship PO
    */

    PROCEDURE autocreate_po_from_req (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_so_new_line_id NUMBER, pv_po_number IN VARCHAR2, pn_line_num NUMBER
                                      , pn_new_line_num OUT NUMBER)
    IS
        ln_interface_header_id   NUMBER;
        ln_interface_line_id     NUMBER;
        ln_agent_id              NUMBER;
        ln_vendor_id             NUMBER;
        ln_vendor_site_id        NUMBER;
        ln_currency_code         VARCHAR2 (10);
        ln_po_org_id             NUMBER;
        ln_req_org_id            NUMBER;
        l_return_status          VARCHAR2 (1);
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000);
        x_num_lines_processed    NUMBER;
        l_document_number        apps.PO_HEADERS_ALL.segment1%TYPE;
        ln_requisition_line_id   NUMBER;
        ln_po_header_id          NUMBER;
        ln_line_num              NUMBER;
    BEGIN
        BEGIN
            SELECT apps.po_headers_interface_s.NEXTVAL
              INTO ln_interface_header_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in getting headers interface sequence in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT po_header_id, agent_id, vendor_id,
                   vendor_site_id, currency_code, org_id
              INTO ln_po_header_id, ln_agent_id, ln_vendor_id, ln_vendor_site_id,
                                  ln_currency_code, ln_po_org_id
              FROM apps.po_headers_all
             WHERE segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in getting header_id, agent_id, vendor info in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            INSERT INTO apps.po_headers_interface (interface_header_id, interface_source_code, batch_id, process_code, /* This used to be process_flag */
                                                                                                                       action, /* This used to be action_type_code */
                                                                                                                               document_type_code, document_subtype, document_num, group_code, vendor_id, vendor_site_id, release_num, release_date, agent_id, currency_code, rate_type_code, /* This used to be rate_type */
                                                                                                                                                                                                                                                                                              rate_date, rate, vendor_list_header_id, --     quote_type_lookup_code, <-- no longer in headers_interface
                                                                                                                                                                                                                                                                                                                                      --     quotation_class_code,   <-- no longer in headers_interface
                                                                                                                                                                                                                                                                                                                                      --DPCARD{
                                                                                                                                                                                                                                                                                                                                      pcard_id, --DPCARD}
                                                                                                                                                                                                                                                                                                                                                creation_date, created_by, last_update_date, last_updated_by
                                                   , org_id,      --<R12 MOAC>
                                                             style_id) --<R12 STYLES PHASE II >
                     VALUES (ln_interface_header_id,  --x_interface_header_id,
                             'PO',
                             ln_interface_header_id,             --x_batch_id,
                             'ADD',                  --x_action_type_code_hdr,
                             'ADD',                         --x_document_mode,
                             'PO',                          --x_document_type,
                             'STANDARD',                 --x_document_subtype,
                             pv_po_number,                       --x_segment1,
                             'DEFAULT',                        --x_group_code,
                             ln_vendor_id,                      --x_vendor_id,
                             ln_vendor_site_id,            --x_vendor_site_id,
                             NULL,                         --x_release_number,
                             NULL,                           --x_release_date,
                             ln_agent_id,                        --x_agent_id,
                             ln_currency_code,              --x_currency_code,
                             NULL,                              --x_rate_type,
                             SYSDATE,                           --x_rate_date,
                             NULL,                                   --x_rate,
                             NULL,                  --x_vendor_list_header_id,
                             -- x_quote_type_lookup_code,
                             -- x_quotation_class_code,
                             --DPCARD{
                             NULL,                               --x_pcard_id,
                             --DPCARD}
                             SYSDATE,                       --x_creation_date,
                             pn_user_id,                       --x_created_by,
                             SYSDATE,                    --x_last_update_date,
                             pn_user_id,                  --x_last_updated_by,
                             ln_po_org_id, --l_purchasing_org_id,  --<R12 MOAC>
                             APPS.PO_DOC_STYLE_GRP.get_standard_doc_style); --l_style_id);          --<R12 STYLES PHASE II >
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while inserting data into headers interface in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT apps.po_lines_interface_s.NEXTVAL
              INTO ln_interface_line_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error getting line sequence number in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT MAX (line_num) + 1
              INTO ln_line_num
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.segment1 = pv_po_number
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in getting max line num in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        pn_new_line_num   := ln_line_num;

        BEGIN
            SELECT odss.requisition_line_id, prla.org_id
              INTO ln_requisition_line_id, ln_req_org_id
              FROM apps.oe_drop_ship_sources odss, apps.po_requisition_lines_all prla
             WHERE     odss.line_id = pn_so_new_line_id
                   AND odss.requisition_line_id = prla.requisition_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in requisition line id, org id in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;



        BEGIN
            INSERT INTO apps.po_lines_interface (interface_header_id,
                                                 interface_line_id,
                                                 action, /* This used to be action_type_code */
                                                 line_num,
                                                 shipment_num,
                                                 requisition_line_id,
                                                 creation_date,
                                                 created_by,
                                                 from_header_id,     -- GA FPI
                                                 from_line_id,       -- GA FPI
                                                 consigned_flag, -- CONSIGNED FPI
                                                 contract_id,      -- <GC FPJ>
                                                 last_update_date,
                                                 last_updated_by)
                 VALUES (ln_interface_header_id,      --x_interface_header_id,
                                                 ln_interface_line_id, --x_interface_line_id,
                                                                       'ADD', --'x_action_type_code_line,
                         ln_line_num,                            --x_line_num,
                                      NULL, ln_requisition_line_id, --x_requisition_line_id,1467322
                         SYSDATE,                           --x_creation_date,
                                  pn_user_id,                  --x_created_by,
                                              NULL, --x_src_header_id,    -- GA FPI
                         NULL,                -- x_src_line_id,      -- GA FPI
                               NULL,    --x_consigned_flag,   -- CONSIGNED FPI
                                     NULL,   --l_contract_id,      -- <GC FPJ>
                         SYSDATE,                        --x_last_update_date,
                                  pn_user_id);           --x_last_updated_by);
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while inserting data in to lines interface in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        COMMIT;


        BEGIN
            APPS.PO_INTERFACE_S.create_documents (
                p_api_version                => 1.0,
                x_return_status              => l_return_status,
                x_msg_count                  => l_msg_count,
                x_msg_data                   => l_msg_data,
                p_batch_id                   => ln_interface_header_id,
                p_req_operating_unit_id      => ln_req_org_id,
                p_purch_operating_unit_id    => ln_po_org_id,
                x_document_id                => ln_po_header_id,
                x_number_lines               => x_num_lines_processed,
                x_document_number            => l_document_number,
                -- Bug 3648268 Use lookup code instead of hardcoded value
                p_document_creation_method   => 'AUTOCREATE',     -- <DBI FPJ>
                p_orig_org_id                => ln_po_org_id      --<R12 MOAC>
                                                            );
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error in PO_INTERFACE_S.create_documents call in autocreate po procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Autocareate po procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END autocreate_po_from_req;

    /*
    We cannot update Unit Price through Standard API on PO line if it is a Dropship Order.
    We can update it through Private API, the below procedure is used for the same
    */

    PROCEDURE update_drop_ship_po_line (pn_err_code       OUT NUMBER,
                                        pv_err_message    OUT VARCHAR2,
                                        pn_user_id            NUMBER,
                                        pn_line_num           NUMBER,
                                        pn_new_line_num       NUMBER,
                                        pn_shipment_num       NUMBER,
                                        pv_po_number          VARCHAR2,
                                        pn_unit_price         NUMBER)
    IS
        CURSOR c_rec IS
            SELECT pla.ROWID, pla.*
              FROM apps.po_lines_all pla, apps.po_headers_all pha
             WHERE     pla.po_header_id = pha.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_new_line_num;

        CURSOR c_rec_old_line IS
            SELECT pla.ROWID, pla.*
              FROM apps.po_lines_all pla, apps.po_headers_all pha
             WHERE     pla.po_header_id = pha.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
    BEGIN
        FOR po_rec IN c_rec
        LOOP
            FOR po_rec_old_line IN c_rec_old_line
            LOOP
                apps.mo_global.set_policy_context ('S', po_rec.org_id);

                APPS.PO_LINES_PKG_SUD.update_row (
                    x_rowid                      => po_rec.ROWID,
                    x_po_line_id                 => po_rec.po_line_id,
                    x_last_update_date           => SYSDATE,
                    x_last_updated_by            => pn_user_id,
                    x_po_header_id               => po_rec.po_header_id,
                    x_line_type_id               => po_rec.line_type_id,
                    x_line_num                   => po_rec.line_num,
                    x_last_update_login          => pn_user_id,
                    x_item_id                    => po_rec.item_id,
                    x_item_revision              => po_rec.item_revision,
                    x_category_id                => po_rec.category_id,
                    x_item_description           => po_rec.item_description,
                    x_unit_meas_lookup_code      => po_rec.unit_meas_lookup_code,
                    x_quantity_committed         => po_rec.quantity_committed,
                    x_committed_amount           => po_rec.committed_amount,
                    x_allow_price_override_flag   =>
                        po_rec.allow_price_override_flag,
                    x_not_to_exceed_price        => po_rec.not_to_exceed_price,
                    x_list_price_per_unit        => po_rec.list_price_per_unit,
                    x_base_unit_price            => pn_unit_price, --po_rec.Base_Unit_Price
                    x_unit_price                 => pn_unit_price,
                    x_quantity                   => po_rec.quantity,
                    x_un_number_id               => po_rec.un_number_id,
                    x_hazard_class_id            => po_rec.hazard_class_id,
                    x_note_to_vendor             => po_rec.note_to_vendor-----<<<------
                                                                         ,
                    x_from_header_id             => po_rec.from_header_id,
                    x_from_line_id               => po_rec.from_line_id,
                    x_from_line_location_id      => po_rec.from_line_location_id,
                    x_min_order_quantity         => po_rec.min_order_quantity,
                    x_max_order_quantity         => po_rec.max_order_quantity,
                    x_qty_rcv_tolerance          => po_rec.qty_rcv_tolerance,
                    x_over_tolerance_error_flag   =>
                        po_rec.over_tolerance_error_flag,
                    x_market_price               => po_rec.market_price,
                    x_unordered_flag             => po_rec.unordered_flag,
                    x_closed_flag                => po_rec.closed_flag,
                    x_user_hold_flag             => po_rec.user_hold_flag,
                    x_cancel_flag                => po_rec.cancel_flag,
                    x_cancelled_by               => po_rec.cancelled_by,
                    x_cancel_date                => po_rec.cancel_date,
                    x_cancel_reason              => po_rec.cancel_reason,
                    x_firm_status_lookup_code    => 'Y'--po_rec.Firm_Status_Lookup_Code
                                                       ,
                    x_firm_date                  => po_rec.Firm_Date,
                    x_vendor_product_num         => po_rec.vendor_product_num,
                    x_contract_num               => po_rec.contract_num,
                    x_taxable_flag               => po_rec.taxable_flag,
                    x_tax_code_id                => po_rec.tax_code_id,
                    x_type_1099                  => po_rec.type_1099,
                    x_capital_expense_flag       => po_rec.capital_expense_flag,
                    x_negotiated_by_preparer_flag   =>
                        po_rec.negotiated_by_preparer_flag,
                    x_attribute_category         =>
                        po_rec_old_line.attribute_category,
                    x_attribute1                 => po_rec_old_line.attribute1,
                    x_attribute2                 => po_rec_old_line.attribute2,
                    x_attribute3                 => po_rec_old_line.attribute3,
                    x_attribute4                 => po_rec_old_line.attribute4,
                    x_attribute5                 => po_rec_old_line.attribute5,
                    x_attribute6                 => po_rec_old_line.attribute6,
                    x_attribute7                 => po_rec_old_line.attribute7,
                    x_attribute8                 => po_rec_old_line.attribute8,
                    x_attribute9                 => po_rec_old_line.attribute9,
                    x_attribute10                => po_rec_old_line.attribute10,
                    x_reference_num              =>
                        po_rec_old_line.reference_num,
                    x_attribute11                =>
                          pn_unit_price
                        - (NVL (po_rec_old_line.attribute8, 0) + NVL (po_rec_old_line.attribute9, 0)),
                    x_attribute12                => po_rec_old_line.attribute12,
                    x_attribute13                => 'True', -- POC negotiation flag,
                    x_attribute14                => po_rec_old_line.attribute14,
                    x_attribute15                => po_rec_old_line.attribute15,
                    x_min_release_amount         => po_rec.min_release_amount,
                    x_price_type_lookup_code     =>
                        po_rec.price_type_lookup_code,
                    x_closed_code                => po_rec.closed_code,
                    x_price_break_lookup_code    =>
                        po_rec.price_break_lookup_code,
                    x_ussgl_transaction_code     =>
                        po_rec.ussgl_transaction_code,
                    x_government_context         => po_rec.government_context,
                    x_closed_date                => po_rec.closed_date,
                    x_closed_reason              => po_rec.closed_reason,
                    x_closed_by                  => po_rec.closed_by,
                    x_transaction_reason_code    =>
                        po_rec.transaction_reason_code,
                    x_global_attribute_category   =>
                        po_rec.global_attribute_category,
                    x_global_attribute1          => po_rec.global_attribute1,
                    x_global_attribute2          => po_rec.global_attribute2,
                    x_global_attribute3          => po_rec.global_attribute3,
                    x_global_attribute4          => po_rec.global_attribute4,
                    x_global_attribute5          => po_rec.global_attribute5,
                    x_global_attribute6          => po_rec.global_attribute6,
                    x_global_attribute7          => po_rec.global_attribute7,
                    x_global_attribute8          => po_rec.global_attribute8,
                    x_global_attribute9          => po_rec.global_attribute9,
                    x_global_attribute10         => po_rec.global_attribute10,
                    x_global_attribute11         => po_rec.global_attribute11,
                    x_global_attribute12         => po_rec.global_attribute12,
                    x_global_attribute13         => po_rec.global_attribute13,
                    x_global_attribute14         => po_rec.global_attribute14,
                    x_global_attribute15         => po_rec.global_attribute15,
                    x_global_attribute16         => po_rec.global_attribute16,
                    x_global_attribute17         => po_rec.global_attribute17,
                    x_global_attribute18         => po_rec.global_attribute18,
                    x_global_attribute19         => po_rec.global_attribute19,
                    x_global_attribute20         => po_rec.global_attribute20,
                    x_expiration_date            => po_rec.expiration_date,
                    x_base_uom                   => po_rec.base_uom,
                    x_base_qty                   => po_rec.base_qty,
                    x_secondary_uom              => po_rec.secondary_uom,
                    x_secondary_qty              => po_rec.secondary_qty,
                    x_qc_grade                   => po_rec.qc_grade,
                    x_oke_contract_header_id     =>
                        po_rec.oke_contract_header_id,
                    x_oke_contract_version_id    =>
                        po_rec.oke_contract_version_id,
                    x_secondary_unit_of_measure   =>
                        po_rec.secondary_unit_of_measure,
                    x_secondary_quantity         => po_rec.secondary_quantity,
                    x_preferred_grade            => po_rec.preferred_grade,
                    p_contract_id                => po_rec.contract_id,
                    x_job_id                     => po_rec.job_id,
                    x_contractor_first_name      =>
                        po_rec.contractor_first_name,
                    x_contractor_last_name       => po_rec.contractor_last_name,
                    x_assignment_start_date      => po_rec.start_date,
                    x_amount_db                  => po_rec.amount,
                    p_manual_price_change_flag   =>
                        po_rec.manual_price_change_flag,
                    p_ip_category_id             => po_rec.ip_category_id);


                UPDATE apps.po_line_locations_all
                   SET price_override   = pn_unit_price
                 WHERE po_line_id = po_rec.po_line_id AND shipment_num = 1;
            END LOOP;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Update dropship PO line procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_drop_ship_po_line;

    --  Purpose : Procedure used to update POC flag to False, this is invoked by SOA only when POA is initiated due to POC interface

    PROCEDURE UPDATE_POC_FLAG (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pv_po_number VARCHAR2)
    IS
        CURSOR cur_po IS
            SELECT pla.*
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.segment1 = pv_po_number
                   AND pha.po_header_id = pla.po_header_id;

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        FOR rec_po IN cur_po
        LOOP
            IF (rec_po.attribute13 = 'True')
            THEN
                BEGIN
                    UPDATE apps.po_lines_all           -- POC Negotiation flag
                       SET attribute13   = 'False'
                     WHERE     line_num = rec_po.line_num
                           AND po_header_id = rec_po.po_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error while updating POC Negotiation flag'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;
            END IF;
        END LOOP;



        COMMIT;

        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
        THEN
            pn_err_code   := 0;
            pv_err_message   :=
                   'POC Flags for PO: '
                || pv_po_number
                || ' got updated Successfully';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Update POC Flag Procedure for PO: '
                || pv_po_number
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_poc_flag;

    PROCEDURE approve_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id IN NUMBER
                          , pv_po_number IN VARCHAR2)
    IS
        ln_header_id       NUMBER;
        ln_agent_id        NUMBER;
        ln_resp_id         NUMBER;
        ln_resp_appl_id    NUMBER;
        ln_org_id          NUMBER;
        ln_user_id         NUMBER;
        lv_approved_flag   VARCHAR2 (100);
        ln_loop_cnt        NUMBER := 0;
        X_ERROR_TEXT       VARCHAR2 (1000);
        X_RET_STAT         VARCHAR2 (1000);
    BEGIN
        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.po_headers_all
             WHERE segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name      --'MO: Security Profile'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name || '%' --'Deckers Purchasing User%'
                   AND fpov.profile_option_value IN
                           (SELECT security_profile_id
                              FROM apps.per_security_organizations
                             WHERE organization_id = ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.mo_global.init ('PO');
        apps.mo_global.set_policy_context ('S', ln_org_id);


        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pha.approved_flag
              INTO ln_header_id, ln_agent_id, lv_approved_flag
              FROM apps.po_headers_all pha
             WHERE 1 = 1 AND pha.segment1 = pv_po_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting header id, agent id, approved flag in Approve PO procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        IF (NVL (lv_approved_flag, 'N') <> 'Y')
        THEN
            LOOP
                ln_loop_cnt   := ln_loop_cnt + 1;

                BEGIN
                    APPS.PO_REQAPPROVAL_INIT1.Start_WF_Process (
                        ItemType                => 'POAPPRV',
                        ItemKey                 => 100,
                        WorkflowProcess         => 'POAPPRV_TOP',
                        ActionOriginatedFrom    => 'PO_FORM',
                        DocumentID              => ln_header_id,
                        DocumentNumber          => pv_po_number,
                        PreparerID              => ln_agent_id,
                        DocumentTypeCode        => 'PO',
                        DocumentSubtype         => 'STANDARD',
                        SubmitterAction         => 'APPROVE'   --''INCOMPLETE'
                                                            ,
                        forwardToID             => NULL    --null-- EMPLOYEEID
                                                       ,
                        forwardFromID           => ln_agent_id,
                        DefaultApprovalPathID   => NULL,
                        Note                    => NULL,
                        printFlag               => 'N');
                --                                            apps.do_po_purch_order_utils_pvt.approve_po(p_po_header_id => ln_header_id,
                --                                                                                x_error_text => x_error_text,
                --                                                                                x_ret_stat => x_ret_stat);
                --
                --                                                    apps.fnd_file.put_line(fnd_file.LOG,'Error text:'||x_error_text);
                --                                                    apps.fnd_file.put_line(fnd_file.LOG,'Error stat:'||x_ret_stat);

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error in approval work flow in Approve PO procedure'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;

                COMMIT;

                BEGIN
                    SELECT pha.po_header_id, pha.agent_id, pha.approved_flag
                      INTO ln_header_id, ln_agent_id, lv_approved_flag
                      FROM apps.po_headers_all pha
                     WHERE 1 = 1 AND pha.po_header_id = ln_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error while getting Approval Flag in Approve PO procedure'
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;

                EXIT WHEN lv_approved_flag = 'Y' OR ln_loop_cnt = 3;
            END LOOP;
        END IF;

        IF lv_approved_flag <> 'Y'
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Approve PO procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Approve PO procedure'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END approve_po;

    --  Purpose : Procedure used to update POC flag to False, this is invoked by SOA only when POA is initiated due to POC interface

    PROCEDURE main_proc_factory_site_line ( -- This procedure is invoked from SOA as part of factory site changes on PO line
        pn_err_code              OUT NUMBER,
        pv_err_message           OUT VARCHAR2,
        pn_line_num           IN     NUMBER,
        pv_po_number          IN     VARCHAR2,
        pv_new_factory_site   IN     VARCHAR2)
    IS
        ln_user_id            NUMBER;
        ln_org_id             NUMBER;
        ln_resp_id            NUMBER;
        ln_resp_appl_id       NUMBER;
        ln_count              NUMBER;
        lv_old_factory_site   VARCHAR2 (100);

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting count in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT pla.attribute7
              INTO lv_old_factory_site
              FROM apps.po_headers_all pha, apps.po_lines_all pla
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting count in Main Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;



        IF ln_count <> 0
        THEN
            IF NVL (lv_old_factory_site, 'X') <> pv_new_factory_site
            THEN
                BEGIN
                    UPDATE apps.po_lines_all
                       SET attribute7 = pv_new_factory_site, last_update_date = SYSDATE
                     WHERE     po_header_id =
                               (SELECT po_header_id
                                  FROM apps.po_headers_all
                                 WHERE segment1 = pv_po_number)
                           AND line_num = pn_line_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pn_err_code   := SQLCODE;
                        pv_err_message   :=
                               'Error while Updating po line in Main Procedure '
                            || '-'
                            || SUBSTR (SQLERRM, 1, 900);
                END;
            ELSE
                pn_err_code   := 1;
                pv_err_message   :=
                    'Factory Site not updated, as there is no change in the factory site';
            END IF;
        ELSE
            pn_err_code   := 1;
            pv_err_message   :=
                'Record doesnt exist in Oracle, please check if it is a valid PO number/Line number';
        END IF;

        COMMIT;

        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
        THEN
            pn_err_code      := 0;
            pv_err_message   := 'SUCCESS';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Main Procedure Factory site change line '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END main_proc_factory_site_line;

    FUNCTION get_so_hold_status (pn_so_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_hold_count    NUMBER;
        pn_err_code      NUMBER;
        pv_err_message   VARCHAR2 (400);
    BEGIN
          SELECT COUNT (1) "Hold Count"
            INTO ln_hold_count
            FROM oe_order_lines_all hold_lines, oe_order_headers_all ooha, oe_order_holds_all holds,
                 oe_hold_sources_all ohsa, oe_hold_releases ohr, oe_hold_definitions ohd
           WHERE     1 = 1
                 AND holds.released_flag = 'N'
                 AND ohd.name = 'Credit Check Failure'
                 AND holds.line_id = hold_lines.line_id(+)
                 AND holds.header_id = hold_lines.header_id(+)
                 AND holds.hold_release_id = ohr.hold_release_id(+)
                 AND holds.hold_source_id = ohsa.hold_source_id
                 AND ohsa.hold_id = ohd.hold_id
                 AND holds.header_id = ooha.header_id
                 AND ooha.header_id = pn_so_header_id
        ORDER BY ohsa.hold_source_id;

        RETURN ln_hold_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in get_so_hold_status Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END get_so_hold_status;

    PROCEDURE release_so_hold ( -- This procedure is invoked to release hold on SO
                               pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_so_header_id IN NUMBER
                               , pn_user_id IN NUMBER)
    IS
        vReturnStatus     VARCHAR2 (240);
        vMsgCount         NUMBER := 0;
        vMsg              VARCHAR2 (2000);
        v_order_tbl       OE_HOLDS_PVT.ORDER_TBL_TYPE;
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;
        ln_hold_id        NUMBER;
        ln_ORG_id         NUMBER;
    BEGIN
        BEGIN
            SELECT ohsa.hold_id
              INTO ln_hold_id
              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd
             WHERE     1 = 1
                   AND ohd.name = 'Credit Check Failure'
                   AND holds.hold_source_id = ohsa.hold_source_id
                   AND ohsa.hold_id = ohd.hold_id
                   AND ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Hold Id in Release Hold Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        -- Set Org Context
        BEGIN
            SELECT org_id
              INTO ln_org_id
              FROM apps.oe_order_headers_all
             WHERE header_id = pn_so_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while getting Org id in Release SO Procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name = 'MO: Operating Unit'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           'Deckers Order Management User' || '%' --'Deckers Order Management User%'
                   AND fpov.profile_option_value = TO_CHAR (ln_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := gn_resp_id;
                ln_resp_appl_id   := gn_resp_appl_id;
                --lv_err_msg := SUBSTR(SQLERRM,1,900);
                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Error in apps intialize while getting resp id in Release Hold procedure'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.mo_global.Init ('ONT');                       -- Required for R12
        apps.mo_global.Set_org_context (ln_org_id, NULL, 'ONT');
        apps.fnd_global.Set_nls_context ('AMERICAN');
        apps.mo_global.Set_policy_context ('S', ln_org_id); -- Required for R12
        v_order_tbl.DELETE;
        v_order_tbl (1).header_id   := pn_so_header_id;

        apps.OE_HOLDS_PUB.Release_Holds (
            p_api_version           => 1.0,
            p_init_msg_list         => FND_API.G_FALSE,
            p_commit                => FND_API.G_FALSE,
            p_validation_level      => FND_API.G_VALID_LEVEL_FULL,
            p_order_tbl             => v_order_tbl,
            p_hold_id               => ln_hold_id,
            p_release_reason_code   => 'CRED-REL',
            p_release_comment       => NULL,
            x_return_status         => vReturnStatus,
            x_msg_count             => vMsgCount,
            x_msg_data              => vMsg);
        DBMS_OUTPUT.Put_line ('Status of Release Holds ' || vReturnStatus);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in release_so_hold Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END release_so_hold;

    -- Function to check if there is change in the Qty/Unit Price/Promised Date/DFFs

    FUNCTION get_type_of_change (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_po_number IN VARCHAR2
                                 , pn_quantity IN NUMBER, pn_unit_price IN NUMBER, pd_new_promised_date IN DATE)
        RETURN VARCHAR2
    IS
        CURSOR cur_po_values IS
            SELECT pha.segment1 po_number, pha.revision_num, pha.po_header_id,
                   pha.authorization_status, pla.po_line_id, pla.line_num,
                   pha.org_id, pla.unit_price, pola.line_location_id,
                   pola.shipment_num, pla.quantity, pola.promised_date,
                   pola.need_by_date, pha.closed_code
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all pola
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = pola.po_line_id
                   AND NVL (pola.cancel_flag, 'N') <> 'Y'
                   AND NVL (pola.closed_code, 'OPEN') = 'OPEN'
                   --AND NVL (pola.quantity_received, 0) = 0
                   --AND NVL (pola.quantity_billed, 0) = 0
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num
                   AND pha.type_lookup_code = 'STANDARD';

        lv_type_of_change   VARCHAR2 (10);
        ln_cnt              NUMBER := 0;
    BEGIN
        FOR rec IN cur_po_values
        LOOP
            ln_cnt   := ln_cnt + 1;

            IF (pn_quantity <> rec.quantity OR pn_unit_price <> rec.unit_price OR pd_new_promised_date <> TRUNC (rec.promised_date))
            THEN
                lv_type_of_change   := 'QUANTITY';
            ELSE
                lv_type_of_change   := 'DFF';
            END IF;
        END LOOP;

        IF ln_cnt = 0
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'No record for Item Key in Oracle: Get Type Of Change'
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
        END IF;

        RETURN lv_type_of_change;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;

            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in get type of change '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END get_type_of_change;

    PROCEDURE update_po_dffs (pn_err_code               OUT NUMBER,
                              pv_err_message            OUT VARCHAR2,
                              pn_user_id                    NUMBER,
                              pn_line_num                   NUMBER,
                              pn_shipment_num               NUMBER,
                              pn_distrb_num                 NUMBER,
                              pv_po_number           IN     VARCHAR2,
                              pv_shipmethod          IN     VARCHAR2,
                              pd_exfactory_date      IN     DATE,
                              pv_freight_pay_party   IN     VARCHAR2,
                              pn_order_type_id       IN     NUMBER)
    IS
        ln_line_id               NUMBER;
        ln_location_id           NUMBER;
        lv_conf_exfactory_date   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT pla.po_line_id, pola.line_location_id
              INTO ln_line_id, ln_location_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all pola
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pla.po_line_id = pola.po_line_id
                   AND NVL (pola.cancel_flag, 'N') <> 'Y'
                   AND NVL (pola.closed_code, 'OPEN') = 'OPEN'
                   --AND NVL (pola.quantity_received, 0) = 0
                   --AND NVL (pola.quantity_billed, 0) = 0
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num
                   AND pola.shipment_num = pn_shipment_num
                   AND pha.type_lookup_code = 'STANDARD';
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'No record for Item Key in Oracle: Update PO DFFs'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        lv_conf_exfactory_date   :=
            TO_CHAR (
                TO_DATE (TO_CHAR (pd_exfactory_date, 'DD-MON-YYYY'),
                         'DD-MON-RRRR'),
                'RRRR/MM/DD HH24:MI:SS');



        BEGIN
            UPDATE apps.po_line_locations_all
               SET attribute5 = lv_conf_exfactory_date, attribute8 = DECODE (attribute8, NULL, lv_conf_exfactory_date, attribute8), attribute7 = pv_freight_pay_party,
                   attribute10 = pv_shipmethod, last_update_date = SYSDATE, last_updated_by = pn_user_id
             WHERE line_location_id = ln_location_id;

            UPDATE apps.po_lines_all                   -- POC Negotiation flag
               SET attribute13 = 'True', last_update_date = SYSDATE, last_updated_by = pn_user_id
             WHERE po_line_id = ln_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while updating POC Negotiation flag in update dffs proc'
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        IF (pn_order_type_id = 2)              -- If order type is Special VAS
        THEN
            UPDATE XXDO.XXD_ONT_SPECIAL_VAS_INFO_T
               SET xfactory_date = pd_exfactory_date, last_update_date = SYSDATE, last_updated_by = pn_user_id
             WHERE po_line_id = ln_line_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                'Error in Update PO Dffs ' || '-' || SUBSTR (SQLERRM, 1, 900);
    END update_po_dffs;

    PROCEDURE process_special_vas_po (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pn_distrb_num NUMBER, pv_split_flag IN VARCHAR2, pv_po_number IN VARCHAR2, pv_shipmethod IN VARCHAR2, pn_quantity IN NUMBER, pd_exfactory_date IN DATE, pn_unit_price IN NUMBER
                                      , pd_new_promised_date IN DATE, pv_freight_pay_party IN VARCHAR2, pv_original_line_flag IN VARCHAR2)
    IS
        ln_line_num       NUMBER;
        ln_shipment_num   NUMBER;
    BEGIN
        --validate Spilt Flag
        IF    UPPER (pv_split_flag) = 'FALSE'
           OR (UPPER (pv_split_flag) = 'TRUE' AND UPPER (pv_original_line_flag) = 'TRUE') -- Update the PO line
        THEN
            -- DBMS_OUTPUT.put_line ('In  process normal PO Update PO Line');

            update_po_line (pn_err_code, pv_err_message, pn_user_id,
                            pn_line_num, pn_shipment_num, pv_po_number,
                            pn_quantity, pn_unit_price, pd_new_promised_date);

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                --DBMS_OUTPUT.put_line ('In Process normal Update Shipment Line');

                update_shipment_line (pn_err_code,     -- Update Shipment line
                                                   pv_err_message, 'FROM UPDATE', pn_user_id, NULL, -- Original Line number not required
                                                                                                    pn_line_num, NULL, -- Original Shipment Line number not required
                                                                                                                       pn_shipment_num, pv_po_number, pv_shipmethod, pd_exfactory_date, pv_freight_pay_party
                                      , pd_new_promised_date);
            END IF;

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_asn_line (pn_err_code, -- Update ASN line if Packing Manifest is Approved
                                 pv_err_message,
                                 pn_user_id,
                                 pn_line_num,
                                 pn_shipment_num,
                                 pv_po_number,
                                 pn_quantity,
                                 pn_unit_price,
                                 pd_new_promised_date);
            END IF;

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                approve_po (pn_err_code, pv_err_message, pn_user_id,
                            pv_po_number);
            END IF;

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                update_special_vas_line (pn_err_code, pv_err_message, pn_user_id, pn_line_num, pn_shipment_num, pv_po_number, pn_quantity, pn_unit_price, pd_new_promised_date
                                         , pd_exfactory_date);
            END IF;
        ELSE
            insert_po_line (pn_err_code,              -- Insert Split PO lines
                            pv_err_message,
                            pn_user_id,
                            pn_line_num,
                            pn_shipment_num,
                            pn_distrb_num,
                            pv_po_number,
                            pv_shipmethod,
                            pn_quantity,
                            pd_exfactory_date,
                            pn_unit_price,
                            pd_new_promised_date,
                            pv_freight_pay_party,
                            ln_line_num,
                            ln_shipment_num);


            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                approve_po (pn_err_code, pv_err_message, pn_user_id,
                            pv_po_number);
            END IF;



            -- DBMS_OUTPUT.put_line ('In SPLIT');

            IF (pn_err_code IS NULL AND pv_err_message IS NULL)
            THEN
                insert_special_vas_line (pn_err_code,
                                         pv_err_message,
                                         pn_user_id,
                                         pn_line_num,
                                         ln_line_num,       -- new line number
                                         pn_shipment_num,
                                         pv_po_number,
                                         pn_quantity,
                                         pn_unit_price,
                                         pd_new_promised_date,
                                         pd_exfactory_date);
            ELSE
                ROLLBACK;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Special VAS PO Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END process_special_vas_po;

    PROCEDURE update_special_vas_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pn_quantity NUMBER, pn_unit_price NUMBER, pd_new_promised_date DATE
                                       , pd_exfactory_date DATE)
    IS
        ln_api_version                  NUMBER := 1.0;
        lc_init_msg_list                VARCHAR2 (2) := fnd_api.g_true;
        x_return_status                 VARCHAR2 (2);
        x_msg_count                     NUMBER := 0;
        x_msg_data                      VARCHAR2 (255);
        l_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        x_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        ln_serial_number                inv_reservation_global.serial_number_tbl_type;
        x_serial_number                 inv_reservation_global.serial_number_tbl_type;
        x_quantity_reserved             NUMBER;
        x_secondary_quantity_reserved   NUMBER;
        lc_message                      VARCHAR2 (4000);
        ln_line_id                      NUMBER;
        ln_header_id                    NUMBER;
        gn_application_id               NUMBER;
        gn_responsibility_id            NUMBER;
        ln_reservation_id               NUMBER;
    BEGIN
        BEGIN
            SELECT application_id, responsibility_id
              INTO gn_application_id, gn_responsibility_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = 'Inventory';
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while fetching responsibility for reservation. '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        fnd_global.apps_initialize (pn_user_id,
                                    gn_responsibility_id,
                                    gn_application_id);


        BEGIN
            SELECT reservation_id, pha.po_header_id, pla.po_line_id
              INTO ln_reservation_id, ln_header_id, ln_line_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla, xxdo.xxd_ont_special_vas_info_t svas
             WHERE     1 = 1
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num
                   AND pha.type_lookup_code = 'STANDARD'
                   AND pha.po_header_id = svas.po_header_id
                   AND pla.po_line_id = svas.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'No record for Item Key in Oracle: Update SVAS Line '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;


        l_rsv_rec.reservation_id                 := ln_reservation_id;
        x_rsv_rec.reservation_id                 := ln_reservation_id;
        x_rsv_rec.reservation_quantity           := pn_quantity;
        x_rsv_rec.primary_reservation_quantity   := pn_quantity;
        --x_rsv_rec.requirement_date := pd_new_promised_date;
        --l_rsv_rec.last_update_date := sysdate;
        --l_rsv_rec.last_updated_by  := pn_user_id;
        --x_rsv_rec.supply_source_type_id := inv_reservation_global.g_source_type_inv;
        --fnd_file.put_line (            fnd_file.LOG,            'Calling INV_RESERVATION_PUB.UPDATE_RESERVATION API');

        inv_reservation_pub.update_reservation (
            p_api_version_number       => ln_api_version,
            p_init_msg_lst             => lc_init_msg_list,
            x_return_status            => x_return_status,
            x_msg_count                => x_msg_count,
            x_msg_data                 => x_msg_data,
            p_original_rsv_rec         => l_rsv_rec,
            p_to_rsv_rec               => x_rsv_rec,
            p_original_serial_number   => ln_serial_number,
            p_to_serial_number         => x_serial_number);

        IF x_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. (x_msg_count)
            LOOP
                lc_message   := fnd_msg_pub.get (i, 'F');
                lc_message   := REPLACE (lc_message, CHR (0), ' ');
            END LOOP;

            UPDATE xxdo.xxd_ont_special_vas_info_t
               SET error_message = SUBSTR ('Error while updating supply to inventory reservation.through POC ' || lc_message, 1, 4000)
             WHERE reservation_id = ln_reservation_id;

            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error while updating supply to inventory reservation.through POC '
                || '-'
                || lc_message;
        END IF;


        --         ELSE
        --            fnd_file.put_line (
        --               fnd_file.LOG,
        --                  'Successfully Updated the Reservation. Reservation ID = '
        --               || rec_supply_res.reservation_id);
        --         END IF;

        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
        THEN
            BEGIN
                UPDATE XXDO.XXD_ONT_SPECIAL_VAS_INFO_T
                   SET xfactory_date = pd_exfactory_date, po_ordered_qty = pn_quantity, need_by_date = pd_new_promised_date,
                       last_update_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     po_line_id = ln_line_id
                       AND po_header_id = ln_header_id
                       AND reservation_id = ln_reservation_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_err_code   := SQLCODE;
                    pv_err_message   :=
                           'Error while updating Custom table: Update SVAS line '
                        || '-'
                        || SUBSTR (SQLERRM, 1, 900);
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Update Special VAS Line Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END update_special_vas_line;

    PROCEDURE insert_special_vas_line (pn_err_code            OUT NUMBER,
                                       pv_err_message         OUT VARCHAR2,
                                       pn_user_id                 NUMBER,
                                       pn_line_num                NUMBER,
                                       pn_new_line_num            NUMBER,
                                       pn_shipment_num            NUMBER,
                                       pv_po_number               VARCHAR2,
                                       pn_quantity                NUMBER,
                                       pn_unit_price              NUMBER,
                                       pd_new_promised_date       DATE,
                                       pd_exfactory_date          DATE)
    IS
        --pn_reservation_id         NUMBER;
        x_reservation_id                NUMBER;

        CURSOR cur_new_pos (reservation_id NUMBER, line_id NUMBER)
        IS
            SELECT xosv.order_number, mso.sales_order_id, xosv.inventory_item_id,
                   xosv.inventory_org_id, xosv.order_line_id, xosv.po_header_id,
                   xosv.po_number, xosv.supply_identifier, xosv.order_quantity_uom,
                   xosv.ordered_quantity, xosv.request_date, xosv.vas_id,
                   pha.authorization_status
              FROM xxdo.xxd_ont_special_vas_info_t xosv, mtl_sales_orders mso, po_headers_all pha
             WHERE     1 = 1
                   AND xosv.reservation_id = reservation_id
                   AND xosv.po_line_id = line_id
                   AND xosv.order_number = mso.segment1
                   AND pha.segment1 = pv_po_number
                   AND pha.po_header_id = xosv.po_header_id
                   AND mso.segment3 = 'ORDER ENTRY'
                   AND vas_status = 'C'
                   AND NVL (cancelled_status, 'N') <> 'X';

        --AND reservation_id = ln_reservation_id;

        ln_api_version                  NUMBER := 1.0;
        lc_init_msg_list                VARCHAR2 (2) := fnd_api.g_true;
        x_return_status                 VARCHAR2 (2);
        x_msg_count                     NUMBER := 0;
        x_msg_data                      VARCHAR2 (255);
        l_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        x_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        ln_serial_number                inv_reservation_global.serial_number_tbl_type;
        x_serial_number                 inv_reservation_global.serial_number_tbl_type;
        x_quantity_reserved             NUMBER;
        x_secondary_quantity_reserved   NUMBER;
        lc_message                      VARCHAR2 (4000);
        ln_header_id                    NUMBER;
        gn_application_id               NUMBER;
        gn_responsibility_id            NUMBER;
        ln_reservation_id               NUMBER;
        ln_po_header_id                 NUMBER;
        ln_po_line_id                   NUMBER;
        ln_location_id                  NUMBER;
        lc_partial_reservation_flag     VARCHAR2 (2) := fnd_api.g_false;
        lc_force_reservation_flag       VARCHAR2 (2) := fnd_api.g_false;
        lc_validation_flag              VARCHAR2 (2) := fnd_api.g_true;
        lb_partial_reservation_exists   BOOLEAN := FALSE;
        --x_quantity_reserved             NUMBER := 0;
        xn_reservation_id               NUMBER := 0;
    BEGIN
        BEGIN
            SELECT application_id, responsibility_id
              INTO gn_application_id, gn_responsibility_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = 'Inventory';
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'Error while fetching responsibility for reservation. '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        fnd_global.apps_initialize (pn_user_id,
                                    gn_responsibility_id,
                                    gn_application_id);

        DBMS_OUTPUT.PUT_LINE ('Old Line Num:' || pn_line_num);
        DBMS_OUTPUT.PUT_LINE ('New Line Num:' || pn_new_line_num);


        BEGIN
            SELECT reservation_id, pha.po_header_id, pla.po_line_id
              INTO ln_reservation_id, ln_po_header_id, ln_po_line_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla, xxdo.xxd_ont_special_vas_info_t svas
             WHERE     1 = 1
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_line_num
                   AND pha.type_lookup_code = 'STANDARD'
                   AND pha.po_header_id = svas.po_header_id
                   AND pla.po_line_id = svas.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'No record for Item Key in Oracle: Update SVAS Line '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        BEGIN
            SELECT plla.line_location_id
              INTO ln_location_id
              FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
             WHERE     1 = 1
                   AND pha.segment1 = pv_po_number
                   AND pla.line_num = pn_new_line_num
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pn_err_code   := SQLCODE;
                pv_err_message   :=
                       'No record for Item Key in Oracle: Update SVAS Line '
                    || '-'
                    || SUBSTR (SQLERRM, 1, 900);
        END;

        DBMS_OUTPUT.PUT_LINE ('New Location id:' || ln_location_id);
        DBMS_OUTPUT.PUT_LINE ('ln_reservation_id:' || ln_reservation_id);
        DBMS_OUTPUT.PUT_LINE ('Line id:' || ln_po_line_id);


        FOR rec_new_pos IN cur_new_pos (ln_reservation_id, ln_po_line_id)
        LOOP
            IF rec_new_pos.authorization_status = 'APPROVED'
            THEN
                l_rsv_rec.requirement_date               := rec_new_pos.request_date;
                l_rsv_rec.organization_id                := rec_new_pos.inventory_org_id;
                l_rsv_rec.inventory_item_id              :=
                    rec_new_pos.inventory_item_id;
                l_rsv_rec.demand_source_type_id          :=
                    inv_reservation_global.g_source_type_oe;
                l_rsv_rec.demand_source_name             := NULL;
                l_rsv_rec.demand_source_header_id        :=
                    rec_new_pos.sales_order_id;
                l_rsv_rec.demand_source_line_id          :=
                    rec_new_pos.order_line_id;
                l_rsv_rec.primary_uom_code               :=
                    rec_new_pos.order_quantity_uom;
                l_rsv_rec.primary_uom_id                 := NULL;
                l_rsv_rec.reservation_uom_code           :=
                    rec_new_pos.order_quantity_uom;
                l_rsv_rec.reservation_uom_id             := NULL;
                l_rsv_rec.reservation_quantity           := pn_quantity;
                l_rsv_rec.primary_reservation_quantity   := pn_quantity;
                l_rsv_rec.autodetail_group_id            := NULL;
                l_rsv_rec.external_source_code           := NULL;
                l_rsv_rec.external_source_line_id        := NULL;
                l_rsv_rec.supply_source_type_id          :=
                    inv_reservation_global.g_source_type_po;
                l_rsv_rec.supply_source_header_id        :=
                    rec_new_pos.po_header_id;
                l_rsv_rec.supply_source_line_id          := ln_location_id;
                l_rsv_rec.supply_source_line_detail      := NULL;
                l_rsv_rec.subinventory_code              := NULL;
                l_rsv_rec.subinventory_id                := NULL;
                l_rsv_rec.supply_source_name             := NULL;
                l_rsv_rec.revision                       := NULL;
                l_rsv_rec.locator_id                     := NULL;
                l_rsv_rec.lot_number                     := NULL;
                l_rsv_rec.lot_number_id                  := NULL;
                l_rsv_rec.pick_slip_number               := NULL;
                l_rsv_rec.lpn_id                         := NULL;
                l_rsv_rec.attribute_category             := NULL;
                l_rsv_rec.attribute1                     := NULL;
                l_rsv_rec.attribute2                     := NULL;
                l_rsv_rec.attribute3                     := NULL;
                l_rsv_rec.attribute4                     := NULL;
                l_rsv_rec.attribute5                     := NULL;
                l_rsv_rec.attribute6                     := NULL;
                l_rsv_rec.attribute7                     := NULL;
                l_rsv_rec.attribute8                     := NULL;
                l_rsv_rec.attribute9                     := NULL;
                l_rsv_rec.attribute10                    := NULL;
                l_rsv_rec.attribute11                    := NULL;
                l_rsv_rec.attribute12                    := NULL;
                l_rsv_rec.attribute13                    := NULL;
                l_rsv_rec.attribute14                    := NULL;
                l_rsv_rec.attribute15                    := NULL;
                l_rsv_rec.ship_ready_flag                := NULL;
                l_rsv_rec.demand_source_delivery         := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Calling INV_RESERVATION_PUB.CREATE_RESERVATION API');

                -- API to create reservation
                inv_reservation_pub.create_reservation (
                    p_api_version_number       => ln_api_version,
                    p_init_msg_lst             => lc_init_msg_list,
                    p_rsv_rec                  => l_rsv_rec,
                    p_serial_number            => ln_serial_number,
                    p_partial_reservation_flag   =>
                        lc_partial_reservation_flag,
                    p_force_reservation_flag   => lc_force_reservation_flag,
                    p_partial_rsv_exists       =>
                        lb_partial_reservation_exists,
                    p_validation_flag          => lc_validation_flag,
                    x_serial_number            => x_serial_number,
                    x_return_status            => x_return_status,
                    x_msg_count                => x_msg_count,
                    x_msg_data                 => x_msg_data,
                    x_quantity_reserved        => x_quantity_reserved,
                    x_reservation_id           => x_reservation_id);
            ELSE
                x_return_status   := 'E';
                lc_message        :=
                       'PO '
                    || rec_new_pos.po_number
                    || ' is not in Approved status.';

                pn_err_code       := SQLCODE;
                pv_err_message    :=
                       'Special VAS error PO Not in Approved status.through POC '
                    || '-'
                    || lc_message;
            END IF;

            IF x_return_status = fnd_api.g_ret_sts_success
            THEN
                DBMS_OUTPUT.put_line (
                       'Successfully Created the Reservation for SO '
                    || rec_new_pos.order_number
                    || '. Reservation ID = '
                    || x_reservation_id);
            ELSE
                FOR i IN 1 .. (x_msg_count)
                LOOP
                    lc_message   := fnd_msg_pub.get (i, 'F');
                    lc_message   := REPLACE (lc_message, CHR (0), ' ');
                END LOOP;

                pn_err_code   := 1;
                pv_err_message   :=
                       'Error while creating supply based reservation '
                    || '. '
                    || lc_message;
            --            fnd_file.put_line (
            --               fnd_file.LOG,
            --                  'Error while creating supply based reservation for SO '
            --               || rec_new_pos.order_number
            --               || '. '
            --               || lc_message);


            END IF;
        END LOOP;



        IF (pn_err_code IS NULL AND pv_err_message IS NULL)
        THEN
            insert_special_vas_custom_line (pn_err_code, pv_err_message, pn_user_id, pn_line_num, pn_new_line_num, pn_shipment_num, pv_po_number, pn_quantity, pn_unit_price, pd_new_promised_date, pd_exfactory_date, ln_reservation_id
                                            ,            -- Old reservation_id
                                              x_reservation_id -- New reservation_id
                                                              );
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Update Special VAS Line Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END insert_special_vas_line;

    PROCEDURE insert_special_vas_custom_line (pn_err_code OUT NUMBER, pv_err_message OUT VARCHAR2, pn_user_id NUMBER, pn_line_num NUMBER, pn_new_line_num NUMBER, pn_shipment_num NUMBER, pv_po_number VARCHAR2, pn_quantity NUMBER, pn_unit_price NUMBER, pd_new_promised_date DATE, pd_exfactory_date DATE, pn_old_reservation_id NUMBER
                                              , pn_reservation_id NUMBER)
    IS
        CURSOR cur_old_rec (header_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_ont_special_vas_info_t svas
             WHERE     1 = 1
                   AND reservation_id = pn_old_reservation_id
                   AND po_header_id = header_id;

        ln_header_id     NUMBER;
        ln_line_id       NUMBER;
        ln_location_id   NUMBER;
    BEGIN
        SELECT pha.po_header_id, pla.po_line_id, plla.line_location_id
          INTO ln_header_id, ln_line_id, ln_location_id
          FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla
         WHERE     pha.po_header_id = pla.po_header_id
               AND pla.po_line_id = plla.po_line_id
               AND pha.segment1 = pv_po_number
               AND pla.line_num = pn_new_line_num;

        FOR rec IN cur_old_rec (ln_header_id)
        LOOP
            INSERT INTO xxd_ont_special_vas_info_t (vas_id,
                                                    order_header_id,
                                                    order_number,
                                                    ordered_date,
                                                    order_status,
                                                    org_id,
                                                    ship_to_org_id,
                                                    customer_name,
                                                    brand,
                                                    currency_code,
                                                    order_line_id,
                                                    order_line_num,
                                                    inventory_item_id,
                                                    ordered_item,
                                                    ordered_quantity,
                                                    request_date,
                                                    schedule_ship_date,
                                                    order_line_status,
                                                    order_line_cancel_date,
                                                    order_quantity_uom,
                                                    need_by_date,
                                                    attachments_count,
                                                    inventory_org_code,
                                                    inventory_org_id,
                                                    vas_status,
                                                    error_message,
                                                    buyer_id,
                                                    buyer_name,
                                                    demand_subinventory,
                                                    ship_to_location_id,
                                                    list_price_per_unit,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    supply_identifier,
                                                    reservation_id,
                                                    po_header_id,
                                                    po_number,
                                                    vendor_id,
                                                    vendor_name,
                                                    vendor_site_id,
                                                    vendor_site,
                                                    po_line_id,
                                                    po_ordered_qty,
                                                    demand_locator_id,
                                                    demand_locator,
                                                    category_id,
                                                    po_line_num,
                                                    xfactory_date)
                     VALUES (xxdo.xxd_ont_special_vas_info_s.NEXTVAL,
                             rec.order_header_id,
                             rec.order_number,
                             rec.ordered_date,
                             rec.order_status,
                             rec.org_id,
                             rec.ship_to_org_id,
                             rec.customer_name,
                             rec.brand,
                             rec.currency_code,
                             rec.order_line_id,
                             rec.order_line_num,
                             rec.inventory_item_id,
                             rec.ordered_item,
                             rec.ordered_quantity,
                             rec.request_date,
                             rec.schedule_ship_date,
                             rec.order_line_status,
                             rec.order_line_cancel_date,
                             rec.order_quantity_uom,
                             pd_new_promised_date,             -- need by date
                             rec.attachments_count,
                             rec.inventory_org_code,
                             rec.inventory_org_id,
                             rec.vas_status,
                             NULL,
                             rec.buyer_id,
                             rec.buyer_name,
                             rec.demand_subinventory,
                             rec.ship_to_location_id,
                             rec.list_price_per_unit,
                             NULL,
                             SYSDATE,                      -- last_update_date
                             pn_user_id,                  -- last_update_login
                             SYSDATE,                            -- created_by
                             pn_user_id,                     -- creation_login
                             ln_location_id,              -- supply_identifier
                             pn_reservation_id,              -- reservation_id
                             rec.po_header_id,
                             rec.po_number,
                             rec.vendor_id,
                             rec.vendor_name,
                             rec.vendor_site_id,
                             rec.vendor_site,
                             ln_line_id,                         -- po_line_id
                             pn_quantity,                    -- po_ordered_qty
                             rec.demand_locator_id,
                             rec.demand_locator,
                             rec.category_id,
                             pn_new_line_num,                   --New line num
                             pd_exfactory_date               -- Exfactory Date
                                              );
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_err_code   := SQLCODE;
            pv_err_message   :=
                   'Error in Update Special VAS Line Procedure '
                || '-'
                || SUBSTR (SQLERRM, 1, 900);
    END insert_special_vas_custom_line;
END xxdo_gtn_po_collaboration_pkg;
/


GRANT EXECUTE ON APPS.XXDO_GTN_PO_COLLABORATION_PKG TO SOA_INT
/

GRANT EXECUTE, DEBUG ON APPS.XXDO_GTN_PO_COLLABORATION_PKG TO XXDO
/
