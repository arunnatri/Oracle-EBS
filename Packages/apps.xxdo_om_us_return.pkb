--
-- XXDO_OM_US_RETURN  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_OM_US_RETURN
/*
=================================================================
 Created By              : BT Technology Team
 Creation Date           : 28-April-2015
 File Name               : XXDO_OM_US_RETURN.pks
 Incident Num            :
 Description             :
 Latest Version          : 1.0

==================================================================
 Date               Version#    Name                    Remarks
==================================================================
28-April-2015        1.0       BT Technology Team

This is an Detailed US Returns Report to compare Returned quantity vs Over Shipped Vs Under Shipped returns  with return reason code
====================================================================================================================================
*/

AS
    PROCEDURE us_ret_rep (psqlstat                  OUT VARCHAR2,
                          perrproc                  OUT VARCHAR2,
                          p_brand                IN     VARCHAR2,
                          p_customer             IN     VARCHAR2,
                          p_customer_number      IN     VARCHAR2,
                          p_cust_po_num          IN     VARCHAR2,
                          p_order_num            IN     NUMBER,
                          p_creation_date_from   IN     VARCHAR2,
                          p_creation_date_to     IN     VARCHAR2,
                          p_cancel_date_from     IN     VARCHAR2,
                          p_cancel_date_to       IN     VARCHAR2)
    AS
        CURSOR c_om_us_return IS
            SELECT ooha.ORDER_NUMBER
                       AS Order_Number,
                   TO_CHAR (ooha.CREATION_DATE, 'DD-MON-YYYY')
                       AS Creation_Date,
                   TO_CHAR (fnd_date.canonical_to_date (ooha.ATTRIBUTE1),
                            'DD-MON-YYYY')
                       AS Cancel_Date,
                   ooha.FLOW_STATUS_CODE
                       AS Order_Header_status,
                   hp.party_name
                       AS Customer,
                   hp.party_number
                       AS Customer_Number,
                   ooha.CUST_PO_NUMBER
                       AS Customer_PO_Number,
                   ooha.ATTRIBUTE5
                       AS Brand,
                   oola.ORDERED_ITEM
                       AS SKU,
                   oola.ORDERED_QUANTITY
                       AS Qty_on_RMA,
                   oola.SHIPPED_QUANTITY
                       AS Received_Qty,
                   oola.FLOW_STATUS_CODE
                       AS RMA_Order_Line_Status,
                   (SELECT meaning
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'CREDIT_MEMO_REASON'
                           AND lookup_code IN
                                   (SELECT DISTINCT RETURN_REASON_CODE
                                      FROM OE_ORDER_HEADERS_ALL ooha
                                     WHERE order_number =
                                           NVL (p_order_num, '0'))
                           AND LANGUAGE = USERENV ('LANG'))
                       AS RETURN_REASON_CODE_MEANING,
                   oola.UNIT_SELLING_PRICE
                       AS Cost_Unit_on_RMA,
                   (SELECT DISTINCT NAME
                      FROM JTF_RS_SALESREPS jrs
                     WHERE jrs.SALESREP_ID = ooha.SALESREP_ID)
                       AS Sales_Rep
              FROM OE_ORDER_HEADERS_ALL ooha, OE_ORDER_LINES_ALL oola, oe_transaction_types_tl ott,
                   hz_parties hp, hz_cust_accounts hc
             WHERE     ooha.HEADER_ID = oola.HEADER_ID
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND hp.PARTY_ID = hc.PARTY_ID
                   AND hc.CUST_ACCOUNT_ID = ooha.SOLD_TO_ORG_ID
                   AND ott.LANGUAGE = USERENV ('LANG')
                   AND ott.transaction_type_id IN
                           (SELECT ott.transaction_type_id
                              FROM oe_transaction_types_vl OTT, fnd_lookup_values flv
                             WHERE     flv.lookup_type =
                                       'DETAILED_RETURNS_REPORT_ORDERS'
                                   AND flv.LANGUAGE = USERENV ('LANG')
                                   AND flv.enabled_flag = 'Y'
                                   AND FLV.MEANING = OTT.NAME)
                   AND ooha.FLOW_STATUS_CODE IN ('BOOKED', 'CLOSED')
                   AND ooha.SALES_CHANNEL_CODE IN ('WHOLESALE', 'RETAIL')
                   AND ooha.org_id IN
                           (SELECT organization_id
                              FROM hr_operating_units
                             WHERE name IN
                                       ('Deckers US OU', 'Deckers US Retail OU'))
                   AND ooha.ATTRIBUTE5 = NVL (p_brand, ooha.ATTRIBUTE5)
                   AND hp.party_name = NVL (p_customer, hp.party_name)
                   AND hp.party_number =
                       NVL (p_customer_number, hp.party_number)
                   AND HC.ACCOUNT_NUMBER =
                       NVL (p_cust_po_num, HC.ACCOUNT_NUMBER)
                   AND ooha.ORDER_NUMBER =
                       NVL (p_order_num, ooha.ORDER_NUMBER)
                   AND ooha.CREATION_DATE BETWEEN NVL (
                                                      FND_DATE.CANONICAL_TO_DATE (
                                                          p_creation_date_from),
                                                      ooha.CREATION_DATE)
                                              AND NVL (
                                                      FND_DATE.CANONICAL_TO_DATE (
                                                          p_creation_date_to),
                                                      ooha.CREATION_DATE)
                   AND TO_CHAR (fnd_date.canonical_to_date (ooha.ATTRIBUTE1),
                                'DD-MON-YYYY') BETWEEN NVL (
                                                           TRIM (
                                                               p_cancel_date_from),
                                                           (TO_CHAR (fnd_date.canonical_to_date (ooha.ATTRIBUTE1), 'DD-MON-YYYY')))
                                                   AND NVL (
                                                           TRIM (
                                                               p_cancel_date_to),
                                                           (TO_CHAR (fnd_date.canonical_to_date (ooha.ATTRIBUTE1), 'DD-MON-YYYY')));
    BEGIN
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
            'Detailed US Returns Report' || CHR (13) || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               'Date: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY')
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output,
                           'Report Input Parameters' || CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output,
                           RPAD ('=', 23, '=') || CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
            RPAD ('Brand', 29, ' ') || ':' || p_brand || CHR (13) || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Customer', 29, ' ')
            || ':'
            || p_customer
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Customer Number', 29, ' ')
            || ':'
            || p_customer_number
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('Customer PO Number', 29, ' ')
            || ':'
            || p_cust_po_num
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Number', 29, ' ')
            || ':'
            || p_order_num
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Creation Date From', 29, ' ')
            || ':'
            || p_creation_date_from
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Creation Date To', 29, ' ')
            || ':'
            || p_creation_date_to
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Cancel Date From', 29, ' ')
            || ':'
            || p_cancel_date_from
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Cancel Date To', 29, ' ')
            || ':'
            || p_cancel_date_to
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));
        fnd_file.put_line (fnd_file.output, CHR (13) || CHR (10));



        fnd_file.put_line (
            fnd_file.output,
               RPAD ('RMA Order Number', 20, ' ')
            || RPAD ('RMA Creation Date', 20, ' ')
            || RPAD ('RMA Cancel Date', 25, ' ')
            || RPAD ('RMA Order Header status', 25, ' ')
            || RPAD ('Customer', 30, ' ')
            || RPAD ('Customer Number', 20, ' ')
            || RPAD ('Customer PO Number', 25, ' ')
            || RPAD ('Brand', 20, ' ')
            || RPAD ('SKU', 20, ' ')
            || RPAD ('Qty on RMA', 20, ' ')
            || RPAD ('Received Qty', 20, ' ')
            || RPAD ('RMA Order Line Status', 27, ' ')
            || RPAD ('RETURN REASON CODE MEANING', 30, ' ')
            || RPAD ('Cost/Unit on RMA', 20, ' ')
            || RPAD ('Sales Rep', 20, ' ')
            || CHR (13)
            || CHR (10));
        fnd_file.put_line (fnd_file.output,
                           RPAD ('=', 342, '=') || CHR (13) || CHR (10));

        FOR c_om_us_returns IN c_om_us_return
        LOOP
            BEGIN
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (c_om_us_returns.Order_Number, 20, ' ')
                    || RPAD (c_om_us_returns.Creation_Date, 20, ' ')
                    || RPAD (c_om_us_returns.Cancel_Date, 25, ' ')
                    || RPAD (c_om_us_returns.Order_Header_status, 25, ' ')
                    || RPAD (c_om_us_returns.Customer, 30, ' ')
                    || RPAD (c_om_us_returns.Customer_Number, 20, ' ')
                    || RPAD (NVL (c_om_us_returns.Customer_PO_Number, ' '),
                             25,
                             ' ')
                    || RPAD (c_om_us_returns.Brand, 20, ' ')
                    || RPAD (c_om_us_returns.SKU, 20, ' ')
                    || RPAD (c_om_us_returns.Qty_on_RMA, 20, ' ')
                    || RPAD (NVL (c_om_us_returns.Received_Qty, '0'),
                             20,
                             ' ')
                    || RPAD (c_om_us_returns.RMA_Order_Line_Status, 27, ' ')
                    || RPAD (
                           NVL (c_om_us_returns.RETURN_REASON_CODE_MEANING,
                                ' '),
                           30,
                           ' ')
                    || RPAD (c_om_us_returns.Cost_Unit_on_RMA, 20, ' ')
                    || RPAD (c_om_us_returns.Sales_Rep, 20, ' ')
                    || CHR (13)
                    || CHR (10));
            EXCEPTION
                WHEN OTHERS
                THEN
                    perrproc   := 1;
                    psqlstat   := SQLERRM;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Exception1: ' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            perrproc   := 2;
            psqlstat   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Exception2: ' || SQLERRM);
    END;
END XXDO_OM_US_RETURN;
/
