--
-- XXD_UPDATE_PO_FACT_FINISH_DATE  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_UPDATE_PO_FACT_FINISH_DATE"
IS
    /****************************************************************************************
    * Package      : XXD_UPDATE_PO_FACT_FINISH_DATE
    * Author       : BT Technology Team
    * Created      : 21-OCT-2014
    * Program Name : Deckers - PO Factory Finish Date Update Program
    * Description  : Package used by: Deckers - PO Factory Finish Date Update Program
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 20-JUL-2015   BT Technology Team  1.00       Created
    ****************************************************************************************/

    /****************************************************************************************
    * Procedure    : log_message
    * Author       : BT Technology Team
    * Description  : Autonomous transaction block to save error messages in staging table
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 20-JUL-2015   BT Technology Team  1.00       Created
    * 07-JUN-2016   Bala Murugesan      2.00       When a PO line is invoiced, entire PO is excluded from update
    *                                              Code is modified to exclude only the specific PO line;
    *                                              Changes are identified by EXCLUDE_PO_LINE
    * 07-JUN-2016   Bala Murugesan      2.00       Error Message was not updated correctly;
    *                                              Changes are identified by UPDATE_ERROR_MESSAGE
    * 07-JUN-2016   Bala Murugesan      2.00       Redundant Po shipments table was removed from the main cursor
    *                                              Changes are identified by REMOVE_POLA
    * 07-JUN-2016   Bala Murugesan      2.00       New Output is added so that it can imported into Excel
    *                                              Changes are identified by NEW_OUTPUT
    * 13-JUL-2016   Bala Murugesan      2.00       Confirmed Xfactory date is used to derive the PO to be updated.
    *                                              Changes are identified by CONF_DATE
    ****************************************************************************************/
    PROCEDURE log_message (p_status       IN VARCHAR2,
                           p_msg          IN VARCHAR2,
                           p_po_no        IN NUMBER,
                           p_style_no     IN VARCHAR2,
                           p_color        IN VARCHAR2,
                           p_request_id   IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_factory_finish_date_t
           SET status = p_status, --             error_message = SUBSTR(error_message || p_msg,3000) --UPDATE_ERROR_MESSAGE
                                  error_message = SUBSTR (error_message || p_msg, 1, 3000) --UPDATE_ERROR_MESSAGE
         WHERE     po_no = p_po_no
               AND style_no = p_style_no
               AND color = p_color
               AND request_id = p_request_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error updating message for PO#: '
                || p_po_no
                || ' - '
                || SQLERRM);
    END;


    /****************************************************************************************
    * Procedure    : xxd_update_fact_finish_date
    * Author       : BT Technology Team
    * Description  : Main procedure to update factory finish date
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 20-JUL-2015   BT Technology Team  1.00       Created
    ****************************************************************************************/

    PROCEDURE xxd_update_fact_finish_date (err_buf    OUT VARCHAR2,
                                           ret_code   OUT NUMBER)
    IS
        --Cursor to fetch po shipment lines to update factory finish date
        CURSOR fact_finish_date_lines_cur IS
            SELECT DISTINCT stg.po_no, pol.org_id, pol.line_num,
                            pll.po_header_id, pll.po_line_id, pll.line_location_id,
                            mcb.attribute7 style_no, mcb.attribute8 color, pll.attribute4,
                            stg.factory_finish_date
              FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_line_locations_all pll,
                   --                apps.po_line_locations_all pola,  --REMOVE_POLA
                   apps.mtl_system_items_b mtl, mtl_item_categories mic, mtl_categories_b mcb,
                   apps.do_po_details dod, xxdo.xxd_factory_finish_date_t stg
             WHERE     poh.po_header_id = pol.po_header_id
                   --                AND pol.po_line_id = pola.po_line_id   --REMOVE_POLA
                   AND pol.po_line_id = pll.po_line_id
                   AND poh.po_header_id = pll.po_header_id
                   AND pll.attribute_category = 'PO Line Locations Elements'
                   AND pol.po_line_id = dod.po_line_id
                   AND pol.item_id = mtl.inventory_item_id
                   AND NVL (poh.closed_code, 'OPEN') = 'OPEN'
                   AND poh.segment1 = stg.po_no
                   AND mtl.inventory_item_id = mic.inventory_item_id
                   AND mtl.organization_id = mic.organization_id
                   AND mic.category_id = mcb.category_id
                   AND mic.category_set_id = 1
                   AND mcb.attribute7 = stg.style_no
                   AND mcb.attribute8 = stg.color
                   AND dod.ship_to_location_id = stg.ship_to_loc_id
                   --                AND NVL(SUBSTR(pll.attribute4,0,10),'X') =
                   --                     NVL(TO_CHAR (stg.requested_exfactory_date, 'RRRR/DD/MM'),'X')  -- CONF_DATE
                   AND NVL (SUBSTR (pll.attribute5, 0, 10), 'X') =
                       NVL (
                           TO_CHAR (stg.requested_exfactory_date,
                                    'RRRR/MM/DD'),
                           'X')
                   AND stg.status = 'N';


        CURSOR cur_fact_fin_date_oracle (p_request_id NUMBER)
        IS
              SELECT DISTINCT stg.po_no, mcb.attribute7 style_no, mcb.attribute8 color,
                              stg.brand, SUBSTR (pll.attribute4, 1, 10) requested_xfactory_date, TO_CHAR (stg.factory_finish_date, 'RRRR/MM/DD') given_ff_date,
                              SUBSTR (pll.attribute9, 1, 10) oracle_ff_date
                FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_line_locations_all pll,
                     apps.mtl_system_items_b mtl, mtl_item_categories mic, mtl_categories_b mcb,
                     apps.do_po_details dod, xxdo.xxd_factory_finish_date_t stg
               WHERE     poh.po_header_id = pol.po_header_id
                     --                AND pol.po_line_id = pola.po_line_id   --REMOVE_POLA
                     AND pol.po_line_id = pll.po_line_id
                     AND poh.po_header_id = pll.po_header_id
                     AND pll.attribute_category = 'PO Line Locations Elements'
                     AND pol.po_line_id = dod.po_line_id
                     AND pol.item_id = mtl.inventory_item_id
                     AND NVL (poh.closed_code, 'OPEN') = 'OPEN'
                     AND poh.segment1 = stg.po_no
                     AND mtl.inventory_item_id = mic.inventory_item_id
                     AND mtl.organization_id = mic.organization_id
                     AND mic.category_id = mcb.category_id
                     AND mic.category_set_id = 1
                     AND mcb.attribute7 = stg.style_no
                     AND mcb.attribute8 = stg.color
                     AND dod.ship_to_location_id = stg.ship_to_loc_id
                     --                AND NVL(SUBSTR(pll.attribute4,0,10),'X') =
                     --                     NVL(TO_CHAR (stg.requested_exfactory_date, 'RRRR/DD/MM'),'X')  -- CONF_DATE
                     AND NVL (SUBSTR (pll.attribute5, 0, 10), 'X') =
                         NVL (
                             TO_CHAR (stg.requested_exfactory_date,
                                      'RRRR/MM/DD'),
                             'X')
                     AND stg.status = 'S'
                     AND stg.request_id = p_request_id
            ORDER BY 1, 2, 3;


        l_request_id            NUMBER;
        ln_row_cnt_e            NUMBER := 0;
        ln_row_cnt_s            NUMBER := 0;
        l_counter               NUMBER := 1;
        l_invoice_count         NUMBER := 0;

        l_complete              BOOLEAN;
        l_phase                 VARCHAR2 (100);
        l_status                VARCHAR2 (100);
        l_dev_phase             VARCHAR2 (100);
        l_dev_status            VARCHAR2 (100);
        l_message               VARCHAR2 (100);
        l_default_param         VARCHAR2 (100);
        l_get_request_status    BOOLEAN := FALSE;
        le_no_parameter_found   EXCEPTION;
    BEGIN
        --Delete records created before 30 days
        DELETE FROM xxdo.xxd_factory_finish_date_t
              WHERE TRUNC (creation_date) <= TRUNC (SYSDATE) - 30;

        BEGIN
            BEGIN
                --Get parameter default value for Upload program
                SELECT fdfcuv.DEFAULT_VALUE
                  INTO l_default_param
                  FROM fnd_concurrent_programs fcp, fnd_concurrent_programs_tl fcpl, fnd_descr_flex_col_usage_vl fdfcuv,
                       fnd_flex_value_sets ffvs, fnd_lookup_values flv, fnd_application_vl fav
                 WHERE     fcp.concurrent_program_id =
                           fcpl.concurrent_program_id
                       AND fcp.concurrent_program_name =
                           'XXD_PO_FACT_FINISH_DATE_UPLOAD'
                       AND fcpl.language = 'US'
                       AND fav.application_id = fcp.application_id
                       AND fdfcuv.descriptive_flexfield_name =
                           '$SRS$.' || fcp.concurrent_program_name
                       AND ffvs.flex_value_set_id = fdfcuv.flex_value_set_id
                       AND flv.lookup_type(+) = 'FLEX_DEFAULT_TYPE'
                       AND flv.lookup_code(+) = fdfcuv.default_type
                       AND flv.language(+) = USERENV ('LANG')
                       AND fdfcuv.end_user_column_name = 'Folder Name';

                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'XXD_PO_FACT_FINISH_DATE_UPLOAD Default Parameter : '
                    || l_default_param);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_default_param   := NULL;
            END;

            IF l_default_param IS NULL
            THEN
                RAISE le_no_parameter_found;
            END IF;

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Sysdate 1: ' || SYSDATE);
            --Submit upload program to load csv file to staging table
            l_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_PO_FACT_FINISH_DATE_UPLOAD',
                    --description   => 'XXTest Employee Details',
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => l_default_param);
            COMMIT;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'XXD_PO_FACT_FINISH_DATE_UPLOAD request_id ' || l_request_id);

            IF l_request_id > 0
            THEN
                --Loop to Wait till the upload program completeds
                LOOP
                    l_dev_phase    := NULL;
                    l_dev_status   := NULL;
                    --Wait till the upload program completeds
                    l_complete     :=
                        fnd_concurrent.wait_for_request (
                            request_id   => l_request_id,
                            interval     => 1,
                            max_wait     => 1,
                            phase        => l_phase,
                            status       => l_status,
                            dev_phase    => l_dev_phase,
                            dev_status   => l_dev_status,
                            MESSAGE      => l_message);

                    IF ((UPPER (l_dev_phase) = 'COMPLETE') OR (UPPER (l_phase) = 'COMPLETED'))
                    THEN
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Sysdate 3: ' || SYSDATE);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        l_request_id   := apps.fnd_global.conc_request_id;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Main Program request_id' || l_request_id);

        --Update request id for the New records
        UPDATE xxdo.xxd_factory_finish_date_t
           SET request_id   = l_request_id
         WHERE status = 'N';

        COMMIT;
        apps.mo_global.init ('PO');

        --Open cursor to update factory finish date
        FOR rec_lines IN fact_finish_date_lines_cur
        LOOP
            BEGIN
                --Check if po line is already invoices
                SELECT COUNT (apinv.invoice_num)
                  INTO l_invoice_count
                  FROM apps.po_lines_all pol, apps.po_headers_all poh, apps.ap_invoice_distributions_all apd,
                       apps.ap_invoices_all apinv, apps.po_distributions_all pod, apps.po_line_locations_all poll
                 WHERE     pol.po_line_id = poll.po_line_id
                       AND poh.po_header_id = pol.po_header_id
                       AND poll.line_location_id = pod.line_location_id
                       AND apd.invoice_id = apinv.invoice_id
                       AND pod.po_distribution_id = apd.po_distribution_id
                       AND pol.po_line_id = rec_lines.po_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception in checking invoice number for PO line id'
                        || SQLERRM);
            END;

            IF l_invoice_count = 0
            THEN
                BEGIN
                    --Update Factory finish date
                    UPDATE po_line_locations_all
                       SET attribute9 = NVL (TO_CHAR (rec_lines.factory_finish_date, --'RRRR/DD/MM'),
                                                                                     'RRRR/MM/DD'), attribute9), last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                     WHERE line_location_id = rec_lines.line_location_id;

                    log_message (p_status       => 'S',
                                 --                     p_msg          =>    'Factory finish date updated for line#'
                                 --                                       || rec_lines.line_num
                                 --                                       || '. ',
                                 p_msg          => NULL,
                                 p_po_no        => rec_lines.po_no,
                                 p_style_no     => rec_lines.style_no, --EXCLUDE_PO_LINE
                                 p_color        => rec_lines.color, --EXCLUDE_PO_LINE
                                 p_request_id   => l_request_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        log_message (
                            p_status       => 'E',
                            p_msg          =>
                                   'Error updating factory finish date for line#'
                                || rec_lines.line_num
                                || ' '
                                || SQLERRM
                                || '. ',
                            p_po_no        => rec_lines.po_no,
                            p_style_no     => rec_lines.style_no, --EXCLUDE_PO_LINE
                            p_color        => rec_lines.color, --EXCLUDE_PO_LINE
                            p_request_id   => l_request_id);
                END;
            ELSE
                log_message (
                    p_status       => 'E',
                    p_msg          =>
                        'PO Line#' || rec_lines.line_num || ' is invoiced. ',
                    p_po_no        => rec_lines.po_no,
                    p_style_no     => rec_lines.style_no,    --EXCLUDE_PO_LINE
                    p_color        => rec_lines.color,       --EXCLUDE_PO_LINE
                    p_request_id   => l_request_id);
            END IF;
        END LOOP;

        --Records which were not picked up by the cursor are marked as Errored
        UPDATE xxdo.xxd_factory_finish_date_t
           SET status = 'E', error_message = error_message || ' No match found. '
         WHERE request_id = l_request_id AND status = 'N';

        --Output of program
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD (' ', 40, ' ')
            || ' '
            || RPAD ('PO Factory Finish Update Program', 40, ' ')
            || ' '
            || RPAD (' ', 30, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD (' ', 40, ' ')
            || ' '
            || RPAD ('-', 21, '-')
            || ' '
            || RPAD (' ', 30, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'PO Factory Finish Update Program - Errored Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('PO NUMBER', 15, ' ')
            || '|'
            || RPAD ('STYLE', 15, ' ')
            || '|'
            || RPAD ('COLOR', 10, ' ')
            || '|'
            || RPAD ('BRAND', 10, ' ')
            || '|'
            || RPAD ('REQUESTED EX-FACTORY DATE', 30, ' ')
            || '|'
            || RPAD ('FACTORY FINISH DATE', 30, ' ')
            || '|'
            || RPAD ('STATUS', 10, ' ')
            || '|'
            || RPAD ('ERROR MESSAGE', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));

        FOR error_rec
            IN (SELECT stg.po_no, stg.style_no, stg.color,
                       stg.brand, stg.requested_exfactory_date, stg.factory_finish_date,
                       'ERROR' status, stg.error_message
                  FROM xxdo.xxd_factory_finish_date_t stg
                 WHERE stg.status = 'E' AND stg.request_id = l_request_id)
        LOOP
            BEGIN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (NVL (error_rec.po_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.style_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.color, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.brand, ' '), 10, ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               TO_CHAR (error_rec.requested_exfactory_date,
                                        'RRRR/DD/MM'),
                               ' '),
                           30,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               TO_CHAR (error_rec.factory_finish_date,
                                        'RRRR/DD/MM'),
                               ''),
                           30,
                           ' ')
                    || '|'
                    || RPAD (NVL (error_rec.status, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.error_message, '') || ' ',
                             50,
                             ' '));
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error in printing error records output file'
                        || SQLERRM);
            END;

            ln_row_cnt_e   := ln_row_cnt_e + 1;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Errored Records Row Count: ' || ln_row_cnt_e);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Factory Finish Date Update Program - Successfully Processed Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('PO NUMBER', 15, ' ')
            || '|'
            || RPAD ('STYLE', 15, ' ')
            || '|'
            || RPAD ('COLOR', 10, ' ')
            || '|'
            || RPAD ('BRAND', 10, ' ')
            || '|'
            || RPAD ('REQUESTED EX-FACTORY DATE', 30, ' ')
            || '|'
            || RPAD ('FACTORY FINISH DATE', 30, ' ')
            || '|'
            || RPAD ('STATUS', 10, ' ')
            || '|'
            || RPAD ('ERROR MESSAGE', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));

        FOR success_rec
            IN (SELECT stg.po_no, stg.style_no, stg.color,
                       stg.brand, stg.requested_exfactory_date, stg.factory_finish_date,
                       'SUCCESS' status, stg.error_message
                  FROM xxdo.xxd_factory_finish_date_t stg
                 WHERE stg.status = 'S' AND stg.request_id = l_request_id)
        LOOP
            BEGIN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (NVL (success_rec.po_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.style_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.color, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.brand, ' '), 10, ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               TO_CHAR (success_rec.requested_exfactory_date,
                                        'RRRR/DD/MM'),
                               ' '),
                           30,
                           ' ')
                    || '|'
                    || RPAD (
                           NVL (
                               TO_CHAR (success_rec.factory_finish_date,
                                        'RRRR/DD/MM'),
                               ' '),
                           30,
                           ' ')
                    || '|'
                    || RPAD (NVL (success_rec.status, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.error_message, ' '), 50, ' '));
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error in printing Success records output file'
                        || SQLERRM);
            END;

            ln_row_cnt_s   := ln_row_cnt_s + 1;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 30, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Success Records Row Count: ' || ln_row_cnt_s);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');


        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');



        -- NEW_OUTPUT -- Start
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 90, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Factory Finish Date from Oracle for SUCCESS records (For excel upload)');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 90, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');

        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'PO NUMBER|STYLE|COLOR|BRAND|REQUESTED EX-FACTORY DATE|FACTORY FINISH DATE (FILE)|FACTORY FINISH DATE (ORACLE)');

        FOR fact_fin_date_oracle_rec
            IN cur_fact_fin_date_oracle (l_request_id)
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   fact_fin_date_oracle_rec.po_no
                || '|'
                || fact_fin_date_oracle_rec.style_no
                || '|'
                || fact_fin_date_oracle_rec.color
                || '|'
                || fact_fin_date_oracle_rec.brand
                || '|'
                || fact_fin_date_oracle_rec.requested_xfactory_date
                || '|'
                || fact_fin_date_oracle_rec.given_ff_date
                || '|'
                || fact_fin_date_oracle_rec.oracle_ff_date);
        END LOOP;
    -- NEW_OUTPUT -- End

    EXCEPTION
        WHEN le_no_parameter_found
        THEN
            err_buf    :=
                'Parameter not set for Deckers - PO Factory Finish Date Upload program';
            ret_code   := 1;
        WHEN OTHERS
        THEN
            ret_code   := 1;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Exception =' || SQLERRM);
    END;
END xxd_update_po_fact_finish_date;
/
