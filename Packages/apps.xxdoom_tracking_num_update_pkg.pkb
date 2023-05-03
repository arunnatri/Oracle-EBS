--
-- XXDOOM_TRACKING_NUM_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoom_tracking_num_update_pkg
IS
    /*
      REM $Header: XXDOOM_TRACKING_NUM_UPDATE_PKG.PKB 2.0 10-DEC-2013 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM =============================================================================================file:///C:/Users/mbacigalupi/Downloads/ontd0008.sql======
      REM
      REM Name          : XXDOOM_TRACKING_NUM_UPDATE_PKG.PKB
      REM
      REM Procedure     :
      REM Special Notes : Main Procedure called by Concurrent Manager
      REM
      REM Procedure     :
      REM Special Notes :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM History:  Creation Date :16-JAN-2013, Created by : Venkata Rama Battu, Sunera Technologies.
      REM
      REM Modification History
      REM Person                  Date              Version              Comments and changes made
      REM -------------------    ----------         ----------           ------------------------------------
      REM Venkata Rama Battu     16-JAN-2013         1.0                 1. Base lined for delivery
      REM BT TECHNOLOGY TEAM     10-DEC-2014         2.0
      REM ===================================================================================================
      */
    PROCEDURE update_track_num (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_lpn IN VARCHAR2
                                , pv_tracking IN VARCHAR2)
    IS
        lv_lpn_number_tab   tracking_num_type := tracking_num_type ();
        /*------  */
        lv_tracking_tab     tracking_num_type := tracking_num_type ();

        TYPE track_rec IS RECORD
        (
            lpn_number     VARCHAR2 (30),
            track_num      VARCHAR2 (30),
            status_code    VARCHAR2 (1),
            status_msg     VARCHAR2 (2000)
        );

        TYPE track_num_tbl IS TABLE OF track_rec
            INDEX BY BINARY_INTEGER;

        track_tbl           track_num_tbl;
        track_err_tbl       track_num_tbl;
        ln_err_cnt          NUMBER := 0;
        ln_lpn_num          VARCHAR2 (30);
        ln_cnt              NUMBER;
    -- ln_lpn_cnt NUMBER;
    BEGIN
        lv_lpn_number_tab   := g_convert (pv_lpn);
        lv_tracking_tab     := g_convert (pv_tracking);           /*------  */
        track_tbl.DELETE;
        track_err_tbl.DELETE;

        IF lv_lpn_number_tab.COUNT = lv_tracking_tab.COUNT
        THEN
            FOR i IN 1 .. lv_lpn_number_tab.COUNT
            LOOP
                track_tbl (i).lpn_number   := TRIM (lv_lpn_number_tab (i));
                track_tbl (i).track_num    := TRIM (lv_tracking_tab (i));
            END LOOP;
        ELSE
            ln_err_cnt   := 1;
            retcode      := 1;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '============================================================================');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                ' LPN Numbers and Tracking Numbers are not equal.resubmit the program again');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '============================================================================');
        END IF;

        IF ln_err_cnt = 0
        THEN
            ln_cnt   := 0;

            FOR j IN 1 .. track_tbl.COUNT
            LOOP
                ln_lpn_num   := NULL;

                BEGIN
                    SELECT wlpn.license_plate_number
                      INTO ln_lpn_num
                      FROM apps.wms_license_plate_numbers wlpn
                     WHERE wlpn.license_plate_number =
                           TRIM (track_tbl (j).lpn_number);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_lpn_num   := NULL;
                    WHEN OTHERS
                    THEN
                        ln_lpn_num   := NULL;
                END;

                IF ln_lpn_num IS NOT NULL
                THEN
                    UPDATE apps.wsh_delivery_details
                       SET tracking_number   = track_tbl (j).track_num
                     WHERE delivery_detail_id IN
                               (SELECT DISTINCT wdd2.delivery_detail_id
                                  FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                                       apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                                       apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                                 WHERE     wdd.container_name =
                                           wlpn.license_plate_number
                                       AND wdd.source_code = 'WSH'
                                       AND wdd.container_flag = 'Y'
                                       AND wda2.parent_delivery_detail_id =
                                           wdd.delivery_detail_id
                                       AND wnd2.delivery_id =
                                           wda2.delivery_id
                                       AND wdd2.delivery_detail_id =
                                           wda2.delivery_detail_id
                                       AND wcsm2.ship_method_code(+) =
                                           wdd2.ship_method_code
                                       AND wcsm2.enabled_flag(+) = 'Y'
                                       AND wcsm2.organization_id(+) =
                                           wdd2.organization_id
                                       -- in (7, wdd2.organization_id)
                                       AND oola.line_id = wdd2.source_line_id
                                       AND ooha.header_id = oola.header_id
                                       AND wdd.container_name = ln_lpn_num);

                    UPDATE apps.wsh_delivery_details
                       SET tracking_number   = track_tbl (j).track_num
                     WHERE delivery_detail_id IN
                               (SELECT DISTINCT parent_delivery_detail_id
                                  FROM apps.wsh_delivery_assignments
                                 WHERE delivery_detail_id IN
                                           (SELECT DISTINCT
                                                   wdd2.delivery_detail_id
                                              FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                                                   apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                                                   apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                                             WHERE     wdd.container_name =
                                                       wlpn.license_plate_number
                                                   AND wdd.source_code =
                                                       'WSH'
                                                   AND wdd.container_flag =
                                                       'Y'
                                                   AND wda2.parent_delivery_detail_id =
                                                       wdd.delivery_detail_id
                                                   AND wnd2.delivery_id =
                                                       wda2.delivery_id
                                                   AND wdd2.delivery_detail_id =
                                                       wda2.delivery_detail_id
                                                   AND wcsm2.ship_method_code(+) =
                                                       wdd2.ship_method_code
                                                   AND wcsm2.enabled_flag(+) =
                                                       'Y'
                                                   AND wcsm2.organization_id(+) =
                                                       wdd2.organization_id
                                                   -- in (7, wdd2.organization_id)
                                                   AND oola.line_id =
                                                       wdd2.source_line_id
                                                   AND ooha.header_id =
                                                       oola.header_id
                                                   AND wdd.container_name =
                                                       ln_lpn_num));

                    UPDATE apps.wsh_new_deliveries wnd
                       SET wnd.attribute1   = track_tbl (j).track_num
                     WHERE wnd.delivery_id IN
                               (SELECT DISTINCT wnd2.delivery_id
                                  FROM apps.wms_license_plate_numbers wlpn, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda2,
                                       apps.wsh_new_deliveries wnd2, apps.wsh_delivery_details wdd2, apps.wsh_carrier_ship_methods wcsm2,
                                       apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                                 WHERE     wdd.container_name =
                                           wlpn.license_plate_number
                                       AND wdd.source_code = 'WSH'
                                       AND wdd.container_flag = 'Y'
                                       AND wda2.parent_delivery_detail_id =
                                           wdd.delivery_detail_id
                                       AND wnd2.delivery_id =
                                           wda2.delivery_id
                                       AND wdd2.delivery_detail_id =
                                           wda2.delivery_detail_id
                                       AND wcsm2.ship_method_code(+) =
                                           wdd2.ship_method_code
                                       AND wcsm2.enabled_flag(+) = 'Y'
                                       AND wcsm2.organization_id(+) =
                                           wdd2.organization_id
                                       -- in (7, wdd2.organization_id)
                                       AND oola.line_id = wdd2.source_line_id
                                       AND ooha.header_id = oola.header_id
                                       AND wdd.container_name = ln_lpn_num);

                    COMMIT;
                ELSE
                    ln_cnt                               := ln_cnt + 1;
                    track_err_tbl (ln_cnt).lpn_number    :=
                        track_tbl (j).lpn_number;
                    track_err_tbl (ln_cnt).track_num     :=
                        track_tbl (j).track_num;
                    track_err_tbl (ln_cnt).status_code   := 'E';
                    track_err_tbl (ln_cnt).status_msg    :=
                        'LPN Number Does not exist please enter correct LPN Numner';
                END IF;
            END LOOP;
        END IF;

        IF track_err_tbl.COUNT >= 1
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '--------------------- Error Records ------------------------------------');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '   ');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 100, '-')
                || '|');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD ('LPN Number', 30, ' ')
                || '|'
                || RPAD ('Tracking Number', 30, ' ')
                || '|'
                || RPAD ('Error Message', 100, ' ')
                || '|');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 30, '-')
                || '|'
                || RPAD ('-', 100, '-')
                || '|');

            FOR k IN 1 .. track_err_tbl.COUNT
            LOOP
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       '|'
                    || RPAD (NVL (track_err_tbl (k).lpn_number, ' '),
                             30,
                             ' ')
                    || '|'
                    || RPAD (NVL (track_err_tbl (k).track_num, ' '), 30, ' ')
                    || '|'
                    || RPAD (NVL (track_err_tbl (k).status_msg, ' '),
                             100,
                             ' ')
                    || '|');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       '|'
                    || RPAD ('-', 30, '-')
                    || '|'
                    || RPAD ('-', 30, '-')
                    || '|'
                    || RPAD ('-', 100, '-')
                    || '|');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Error occured while Processing Trakcing Number Procedure'
                || SQLERRM);
    END;

    /* ============================================================================================================================

       Function will accept the list of values seperated by comma and returns table of values

       ============================================================================================================================*/
    FUNCTION g_convert (pv_list IN VARCHAR2)
        RETURN tracking_num_type
    AS
        lv_string        VARCHAR2 (32767) := pv_list || ',';
        ln_comma_index   PLS_INTEGER;
        ln_index         PLS_INTEGER := 1;
        l_tab            tracking_num_type := tracking_num_type ();
    BEGIN
        LOOP
            ln_comma_index        := INSTR (lv_string, ',', ln_index);
            EXIT WHEN ln_comma_index = 0;
            l_tab.EXTEND;
            l_tab (l_tab.COUNT)   :=
                SUBSTR (lv_string, ln_index, ln_comma_index - ln_index);
            ln_index              := ln_comma_index + 1;
        END LOOP;

        RETURN l_tab;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while converting the comma seperated to table type');
            RETURN NULL;
    END g_convert;
END;
/
