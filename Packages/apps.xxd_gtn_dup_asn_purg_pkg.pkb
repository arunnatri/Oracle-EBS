--
-- XXD_GTN_DUP_ASN_PURG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GTN_DUP_ASN_PURG_PKG"
IS
    /**********************************************************************************************************
        file name    : XXD_GTN_DUP_ASN_PURG_PKG.pkb
        created on   : 10-NOV-2014
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. Insert the Style/SKU/UPC creation and update message to staging table.
                               1. Insert the TAX creation and update message to staging table.
    ****************************************************************************
       Modification history:
    *****************************************************************************
          NAME:         XXD_GTN_DUP_ASN_PURG_PKG
          PURPOSE:      MIAN PROCEDURE CONTROL_PROC

          REVISIONS:
          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         06/03/2017     INFOSYS       1. Created this package body.
    *********************************************************************
    *********************************************************************/

    gn_userid               NUMBER := apps.fnd_global.user_id;
    gn_resp_id              NUMBER := apps.fnd_global.resp_id;
    gn_app_id               NUMBER := apps.fnd_global.prog_appl_id;
    gn_conc_request_id      NUMBER := apps.fnd_global.conc_request_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    gn_wsale_pricelist_id   NUMBER;
    gn_rtl_pricelist_id     NUMBER;
    gv_debug_enable         VARCHAR2 (10) := 'Y';
    gd_begin_date           DATE;
    gd_end_date             DATE;
    gn_master_orgid         NUMBER;
    ln_ext_count            NUMBER := 0;
    gn_master_org_code      VARCHAR2 (200)
        := apps.fnd_profile.VALUE ('XXDO: ORGANIZATION CODE');

    /****************************************************************************
    * Procedure Name    : msg
    *
    * Description       : The purpose of this procedure is to display log
    *                     messages.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters :
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 6/28/2017     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER:= 1000)
    IS
    BEGIN
        IF gv_debug_enable = 'Y'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.OUTPUT,
                                    'Error In msg procedure' || SQLERRM);
    END;


    PROCEDURE main_proc (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_action IN VARCHAR2
                         , pv_asn_ref IN VARCHAR2)
    IS
        ln_request_id   NUMBER := fnd_global.conc_request_id;
        ln_asn_exists   NUMBER := 0;
        lv_action       VARCHAR2 (50);


        CURSOR c_view IS
            SELECT ship.shipment_id,
                   ship.asn_reference_no,
                   ship.invoice_num,
                   ship.ownership_fob_date,
                   ship.creation_date,
                   cnt.container_id,
                   cnt.container_num,
                   cnt.container_ref,
                   cnt.extract_status,
                   (SELECT COUNT (1)
                      FROM CUSTOM.do_orders ord
                     WHERE ord.container_id = cnt.container_id)
                       AS orderCnt,
                   (SELECT COUNT (1)
                      FROM CUSTOM.do_items item
                     WHERE item.container_id = cnt.container_id)
                       AS itemCnt,
                   (SELECT COUNT (1)
                      FROM CUSTOM.do_cartons cart
                     WHERE cart.container_id = cnt.container_id)
                       AS cartonCnt,
                   (SELECT COUNT (1)
                      FROM PO.rcv_shipment_headers
                     WHERE    shipment_num LIKE
                                  CONCAT (
                                      CONCAT (CONCAT (cnt.shipment_id, '_'),
                                              cnt.container_id),
                                      '%')
                           OR packing_slip = ship.invoice_num)
                       AS rsh
              FROM CUSTOM.do_shipments ship, CUSTOM.do_containers cnt
             WHERE     ship.shipment_id = cnt.shipment_id
                   AND ASN_REFERENCE_NO = pv_asn_ref;

        CURSOR c_rec IS
            SELECT shipment_id
              FROM custom.do_shipments
             WHERE ASN_REFERENCE_NO = pv_asn_ref;
    BEGIN
        lv_action   := pv_action;
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '*****************Input Parameters****************');

        fnd_file.put_line (fnd_file.OUTPUT, 'Action : ' || pv_action);
        fnd_file.put_line (fnd_file.OUTPUT,
                           'ASN Ref Number : ' || pv_asn_ref);


        BEGIN
            SELECT COUNT (1)
              INTO ln_asn_exists
              FROM custom.do_shipments
             WHERE ASN_REFERENCE_NO = pv_asn_ref;
        END;

        IF ln_asn_exists = 0
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, '       ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                'ASN Ref Num :' || pv_asn_ref || ' Doesnt exists in Oracle');
            fnd_file.put_line (
                fnd_file.LOG,
                'ASN Ref Num :' || pv_asn_ref || ' Doesnt exists in Oracle ');
            lv_action   := 'NOACTION';
        END IF;


        IF lv_action = 'DELETE'
        THEN
            FOR rec IN c_rec
            LOOP
                SELECT COUNT (1)
                  INTO ln_ext_count
                  FROM CUSTOM.do_containers
                 WHERE     SHIPMENT_ID = rec.shipment_id
                       AND EXTRACT_STATUS = 'Extracted';

                IF ln_ext_count > 0
                THEN
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'ASN Ref Number : '
                        || pv_asn_ref
                        || ' Cannot be deleted as its already Extracted ');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'ASN Ref Number : '
                        || pv_asn_ref
                        || ' Cannot be deleted as its already Extracted ');
                ELSE
                    --**********BACKUP*************

                    INSERT INTO do_items_bkp
                        (SELECT *
                           FROM custom.do_items
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id IN
                                                            (rec.shipment_id))));

                    INSERT INTO do_cartons_bkp
                        (SELECT *
                           FROM custom.do_cartons
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id IN
                                                            (rec.shipment_id))));

                    INSERT INTO do_orders_bkp
                        (SELECT *
                           FROM custom.do_orders
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id IN
                                                            (rec.shipment_id))));


                    INSERT INTO do_containers_bkp
                        (SELECT *
                           FROM custom.do_containers
                          WHERE shipment_id IN
                                    (SELECT shipment_id
                                       FROM custom.do_shipments
                                      WHERE shipment_id IN (rec.shipment_id)));

                    INSERT INTO do_shipments_bkp
                        (SELECT *
                           FROM custom.do_shipments
                          WHERE shipment_id IN (rec.shipment_id));

                    --*******BACKUP DONE******


                    DELETE FROM
                        custom.do_items
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id =
                                                        rec.shipment_id));

                    DELETE FROM
                        custom.do_cartons
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id =
                                                        rec.shipment_id));

                    DELETE FROM
                        custom.do_orders
                          WHERE container_id IN
                                    (SELECT container_id
                                       FROM custom.do_containers
                                      WHERE shipment_id IN
                                                (SELECT shipment_id
                                                   FROM custom.do_shipments
                                                  WHERE shipment_id =
                                                        rec.shipment_id));

                    DELETE FROM
                        custom.do_containers
                          WHERE shipment_id IN
                                    (SELECT shipment_id
                                       FROM custom.do_shipments
                                      WHERE shipment_id = rec.shipment_id);

                    DELETE FROM custom.do_shipments
                          WHERE shipment_id = rec.shipment_id;

                    IF SQL%ROWCOUNT > 0
                    THEN
                        fnd_file.put_line (fnd_file.OUTPUT, '       ');
                        fnd_file.put_line (
                            fnd_file.OUTPUT,
                               'ASN REFERENCE '
                            || pv_asn_ref
                            || ' has been deleted from Oeacle');
                    END IF;
                END IF;
            END LOOP;
        ELSIF lv_action = 'DETAILS'
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, '               ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '*****************Details Starts******************');

            fnd_file.put_line (fnd_file.OUTPUT, '               ');

            fnd_file.put_line (
                fnd_file.OUTPUT,
                   'ASN REFERENCE NUMBER : '
                || '  CREATION DATE : '
                || '  CONTAINER REF : '
                || '  INVOICE NUM : ');

            FOR v_rec IN c_view
            LOOP
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                       ' '
                    || v_rec.ASN_REFERENCE_NO
                    || '           '
                    || v_rec.CREATION_DATE
                    || '           '
                    || v_rec.CONTAINER_REF
                    || '           '
                    || v_rec.INVOICE_NUM);
            END LOOP;

            fnd_file.put_line (fnd_file.OUTPUT, '               ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '*****************END Details*********************');
        END IF;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.OUTPUT,
                               'Exception occured ' || SQLERRM);
    END main_proc;
END XXD_GTN_DUP_ASN_PURG_PKG;
/
