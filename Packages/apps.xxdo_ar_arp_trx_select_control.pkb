--
-- XXDO_AR_ARP_TRX_SELECT_CONTROL  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_ARP_TRX_SELECT_CONTROL"
AS
    /***************************************************************************************************************************************
        file name    : XXDO_AR_ARP_TRX_SELECT_CONTROL.pkb
        created on   : 19-MAY-2016
        created by   : INFOSYS
        purpose      : package body is a copy of ARP_TRX_SELECT_CONTROL
      **************************************************************************************************************************************
       Modification history:
      **************************************************************************************************************************************


          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         19-MAY-2016     INFOSYS       1.Created to be able to comment billing_cycle_id condition
     ***************************************************************************************************************************************
     ***************************************************************************************************************************************/

    PROCEDURE build_where_clause (P_choice IN VARCHAR2, P_open_invoice IN VARCHAR2, P_cust_trx_type_id IN NUMBER, p_cust_trx_class IN VARCHAR2, P_installment_number IN NUMBER, P_dates_low IN DATE, P_dates_high IN DATE, P_customer_id IN NUMBER, P_customer_class_code IN VARCHAR2, P_trx_number_low IN VARCHAR2, P_trx_number_high IN VARCHAR2, P_batch_id IN NUMBER, P_customer_trx_id IN NUMBER, p_adj_number_low IN VARCHAR2, p_adj_number_high IN VARCHAR2, p_adj_dates_low IN DATE, p_adj_dates_high IN DATE, P_where1 OUT NOCOPY VARCHAR2, P_where2 OUT NOCOPY VARCHAR2, p_table1 OUT NOCOPY VARCHAR2, p_table2 OUT NOCOPY VARCHAR2
                                  , p_call_from IN VARCHAR2 DEFAULT 'INV')
    IS
        /*
         ---------------------------------------------------------------------------------------
        |           |
        |   This procedure return 2 where clauses ( P_where1, P_where2 )   |
        |   base on the following input parameters      |
        |           |
        |      P_choice   mandatory varchar2     |
        |    IN ( 'NEW', 'SEL', 'ONE', 'BATCH', 'ADJ' )  |
        |      P_open_invoice  mandatory varchar2     |
        |    in ( 'Y', 'N' )      |
        |      P_cust_trx_type_id  optional number;    |
        |      P_installment_number optional number;     |
        |      P_dates_low  optional date;      |
        |      P_dates_high  optional date;      |
        |      P_customer_id  optional number;     |
        |      P_customer_class_code optional varchar2;     |
        |      P_trx_number_low  optional varchar2;     |
        |      P_trx_number_high  optional varchar2;    |
        |      P_batch_id   optional number,    |
        |    mandatory if P_choice = 'BATCH';   |
        |      P_customer_trx_id  optional number,    |
        |    mandatory if P_choice = 'ONE';    |
        |           |
        |      part 1 : drivers on trx_dates ( Rel 9 )      |
        |         selects invoices without payment schedules or    |
        |         invoices with null or 0 value in print lead days   |
        |      part 2 : drivers on due_dates ( Rel 9 )      |
        |           selects invoices with positive print lead days and   |
        |         payment schedules       |
        |           |
        |      P_where1 :=          |
        |      FROM   RA_CUSTOMERS                     B,     |
        |             RA_TERMS_LINES                   TL,     |
        |             RA_TERMS                         T,     |
        |             AR_PAYMENT_SCHEDULES             P,     |
        |             RA_CUSTOMER_TRX                  A,     |
        |             RA_CUST_TRX_TYPES                TYPES,     |
        |             AR_LOOKUPS                       L_TYPES     |
        |      WHERE  A.COMPLETE_FLAG = 'Y'       |
        |      AND    A.PRINTING_OPTION IN ('PRI', 'REP')     |
        |      AND    A.BILL_TO_CUSTOMER_ID = B.CUST_ACCOUNT_ID     |
        |      AND    A.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID(+)      |
        |      AND    A.TERM_ID = TL.TERM_ID       |
        |      AND    A.TERM_ID = T.TERM_ID       |
        |      AND    A.CUST_TRX_TYPE_ID = TYPES.CUST_TRX_TYPE_ID;    |
        |      AND    L_TYPES.LOOKUP_TYPE = 'INV/CM/ADJ';     |
        |      AND    L_TYPES.LOOKUP_CODE = DECODE( TYPES.TYPE,'DEP','INV',TYPES.TYPE)  |
        |      AND    NVL(P.TERMS_SEQUENCE_NUMBER,TL.SEQUENCE_NUM)=TL.SEQUENCE_NUM  |
        |      AND    DECODE(P.PAYMENT_SCHEDULE_ID,'',0, NVL(T.PRINTING_LEAD_DAYS,0))=0  |
        |      AND    B.CUST_ACCOUNT_ID = NVL(:P_customer_id,B.CUST_ACCOUNT_ID)   |
        |      AND    A.CUST_TRX_TYPE_ID = NVL(:P_cust_trx_type_id, A.CUST_TRX_TYPE_ID)  |
        |      AND    TL.SEQUENCE_NUM = NVL(:P_installment_number ,TL.SEQUENCE_NUM)  |
        |      AND    DECODE(:P_open_invoice,'Y',       |
        |                DECODE(A.PREVIOUS_CUSTOMER_TRX_ID||A.INITIAL_CUSTOMER_TRX_ID,   |
        |                  '', NVL(P.AMOUNT_DUE_REMAINING,1),1),1) <> 0    |
        |      AND    A.TRX_DATE BETWEEN       |
        |                   TO_DATE(NVL(:P_dates_low, TO_CHAR(TO_DATE('1721424','J'),  |
        |                               'DD-MON-YYYY')),'DD-MON-YYYY')    |
        |               AND TO_DATE(NVL(:P_dates_high, TO_CHAR(TO_DATE('2853311','J'),  |
        |                               'DD-MON-YYYY')),'DD-MON-YYYY')    |
        |      AND    B.CUSTOMER_CLASS_CODE       |
        |             = NVL(:P_customer_class_code, B.CUSTOMER_CLASS_CODE)   |
        |           |
        |      P_where2 :=          |
        |      FROM   RA_CUSTOMERS                     B,     |
        |             RA_TERMS                         T,     |
        |             AR_PAYMENT_SCHEDULES             S,     |
        |             RA_CUSTOMER_TRX                  A,     |
        |             RA_CUST_TRX_TYPES                TYPES,     |
        |             AR_LOOKUPS                       L_TYPES     |
        |      WHERE  A.COMPLETE_FLAG = 'Y'       |
        |      AND    A.PRINTING_OPTION IN ('PRI', 'REP')     |
        |      AND    A.BILL_TO_CUSTOMER_ID = B.CUST_ACCOUNT_ID |
        |      AND    A.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID     |
        |      AND    A.TERM_ID = T.TERM_ID       |
        |      AND    A.CUST_TRX_TYPE_ID = TYPES.CUST_TRX_TYPE_ID;    |
        |      AND    L_TYPES.LOOKUP_TYPE = 'INV/CM/ADJ';     |
        |      AND    L_TYPES.LOOKUP_CODE = DECODE( TYPES.TYPE,'DEP','INV',TYPES.TYPE)  |
        |      AND    B.CUST_ACCOUNT_ID = NVL(:P_customer_id,B.CUST_ACCOUNT_ID)   |
        |      AND    A.CUST_TRX_TYPE_ID = NVL(:P_cust_trx_type_id, A.CUST_TRX_TYPE_ID)  |
        |      AND    P.TERMS_SEQUENCE_NUMBER =       |
        |                   NVL(:P_installment_number ,P.TERMS_SEQUENCE_NUMBER)   |
        |      AND    DECODE(:P_open_invoice,'Y',       |
        |                DECODE(A.PREVIOUS_CUSTOMER_TRX_ID||A.INITIAL_CUSTOMER_TRX_ID,   |
        |                  '', P.AMOUNT_DUE_REMAINING,1),1) <> 0    |
        |      AND    P.DUE_DATE||'' BETWEEN       |
        |                   TO_DATE(NVL(:P_dates_low,TO_CHAR(TO_DATE('1721424','J'),  |
        |                               'DD-MON-YYYY')),'DD-MON-YYYY')    |
        |                   + nvl (T.PRINTING_LEAD_DAYS, 0)     |
        |               AND TO_DATE(NVL(:P_dates_high, TO_CHAR(TO_DATE('2853311','J'),  |
        |                               'DD-MON-YYYY')),'DD-MON-YYYY')    |
        |                   + nvl (T.PRINTING_LEAD_DAYS, 0)     |
        |      AND    B.CUSTOMER_CLASS_CODE       |
        |             = NVL(:P_customer_class_code, B.CUSTOMER_CLASS_CODE)   |
        |           |
        |           |
        |           |
        | (1)  Print New Invoices        |
        |      P_choice   mandatory = 'NEW'     |
        |      P_open_invoice  mandatory varchar2 in ( 'Y', 'N' )   |
        |      P_cust_trx_type_id  optional number;    |
        |      P_installment_number optional number;     |
        |      P_dates_low  optional date;      |
        |      P_dates_high  optional date;      |
        |      P_customer_class_code optional varchar2;     |
        |           |
        |      P_where1 := P_where1 ||        |
        |      AND    A.PRINTING_PENDING = 'Y'       |
        |      AND    TL.SEQUENCE_NUM > NVL(A.LAST_PRINTED_SEQUENCE_NUM,0)   |
        |           |
        |      P_where2 := P_where2 ||        |
        |      AND    A.PRINTING_PENDING = 'Y'       |
        |      AND    P.TERMS_SEQUENCE_NUMBER > NVL(A.LAST_PRINTED_SEQUENCE_NUM,0)  |
        |           |
        |           |
        | (2)  Print Selected invoices ( with trx number low and high )    |
        |      P_choice   mandatory varchar2 = 'SEL'    |
        |      P_open_invoice  mandatory varchar2 in ( 'Y', 'N' )   |
        |      P_cust_trx_type_id  optional number;    |
        |      P_installment_number optional number;     |
        |      P_dates_low  optional date;      |
        |      P_dates_high  optional date;      |
        |      P_trx_number_low  varchar2 not null;     |
        |      P_trx_number_high  varchar2 not null;    |
        |      P_customer_id  optional number;     |
        |      P_customer_class_code optional varchar2;     |
        |           |
        |      P_where1 := P_where1 ||        |
        |      AND    A.TRX_NUMBER BETWEEN :P_trx_number_low AND :P_trx_number_high  |
        |           |
        |      P_where2 := P_where2 ||        |
        |      AND    A.TRX_NUMBER BETWEEN :P_trx_number_low AND :P_trx_number_high  |
        |           |
        |           |
        | (3)  Print Selected invoices        |
        |      P_choice   mandatory varchar2 = 'SEL'    |
        |      P_open_invoice  mandatory varchar2 in ( 'Y', 'N' )   |
        |      P_cust_trx_type_id  optional number;    |
        |      P_installment_number optional number;     |
        |      P_dates_low  optional date;      |
        |      P_dates_high  optional date;      |
        |      P_trx_number_low  optional varchar2;     |
        |      P_trx_number_high  optional varchar2;    |
        |      P_customer_id  optional number;     |
        |      P_customer_class_code optional varchar2;     |
        |           |
        |           |
        | (4)  Print Batch: ( with batch_id )       |
        |      P_choice   mandatory varchar2 = 'BATCH'    |
        |      P_open_invoice  mandatory varchar2 in ( 'Y', 'N' )   |
        |      P_cust_trx_type_id  optional number;    |
        |      P_batch_id   mandatory number;    |
        |      P_customer_class_code optional varchar2;     |
        |           |
        |      P_where1 := P_where1 ||        |
        |      AND    A.BATCH_ID = :P_batch_id       |
        |           |
        |      P_where2 := P_where2 ||        |
        |      AND    A.BATCH_ID = :P_batch_id       |
        |           |
        |           |
        | (5)  Print One: ( with customer_trx_id )      |
        |      P_choice   mandatory varchar2 = 'ONE'    |
        |      P_open_invoice  mandatory varchar2 in ( 'Y', 'N' )   |
        |      P_cust_trx_type_id  optional number;    |
        |      P_customer_trx_id  mandatory number;    |
        |           |
        |      P_where1 := P_where1 ||        |
        |      AND    A.CUSTOMER_TRX_ID = :P_customer_trx_id     |
        |           |
        |      P_where2 := P_where2 ||        |
        |      AND    A.CUSTOMER_TRX_ID = :P_customer_trx_id     |
        |           |
        | (6)  p_adjustments:-         |
        |      Extra Tables: ar_adjustments adj       |
        |           |
        |      p_adj_number_low         |
        |      p_adj_number_high        |
        |      p_trx_number_low         |
        |      p_trx_number_high        |
        |           |
        |      P_where1 := P_where1 ||        |
        |      and    adj.adjustment_number between p_adj_number_low and :p_adj_number_high |
        |      and    adj.apply_date between :p_adj_date_low and :p_adj_date_high  |
        |      and    a.customer_trx_id = adj.customer_trx_id     |
        |      AND    nvl(TL.SEQUENCE_NUM,1) = 1      |
        |           |
        |      P_where2 := P_where2 ||        |
        |      and    adj.adjustment_number between p_adj_number_low and :p_adj_number_high |
        |      and    adj.apply_date between :p_adj_date_low and :p_adj_date_high  |
        |      and    a.customer_trx_id = adj.customer_trx_id     |
        |      AND    nvl(TL.SEQUENCE_NUM,1) = 1      |
        |           |
        | (7) Otherwise          |
        |     P_where1 = ''         |
        |     P_where2 = ''         |
        |           |
        |     return P_where1, P_where2.       |
        |           |
         ---------------------------------------------------------------------------------------*/

        /*----------------------------------------------------------------------+
         | Declare local variables      |
         +----------------------------------------------------------------------*/
        where1            VARCHAR2 (8096);
        where2            VARCHAR2 (8096);
        where3            VARCHAR2 (8096);
        table1            VARCHAR2 (8096);
        table2            VARCHAR2 (8096);

        cr                CHAR (1);
        dates_low         DATE;
        dates_high        DATE;
        adj_dates_low     DATE;
        adj_dates_high    DATE;
        adj_number_low    VARCHAR2 (80);
        adj_number_high   VARCHAR2 (80);
        trx_number_low    VARCHAR2 (80);
        trx_number_high   VARCHAR2 (80);

        sel_new           NUMBER := 1;
        sel_inv           NUMBER := 2;
        sel_sel           NUMBER := 3;
        sel_one           NUMBER := 4;
        sel_batch         NUMBER := 5;
        sel_adj           NUMBER := 6;
        choice            NUMBER;

        p_userenv_lang    VARCHAR2 (4);
        language_code     VARCHAR2 (4);
        p_base_lang       VARCHAR2 (4);
    BEGIN
        /*----------------------------------------------------------------------+
         | initialization        |
         +----------------------------------------------------------------------*/
        where1            := '';
        where2            := '';
        cr                := '
';


        /*----------------------------------------------------------------------+
         | make dates_low := P_dates_low  00:00:00    |
         | make dates_high := P_dates_high 23:59:59   |
         +----------------------------------------------------------------------*/
        dates_low         := TRUNC (P_dates_low);
        dates_high        := arp_standard.CEIL (P_dates_high);

        adj_dates_low     := TRUNC (p_adj_dates_low);
        adj_dates_high    := arp_standard.CEIL (p_adj_dates_high);


        /*----------------------------------------------------------------------+
         | Protect every occurance of single quote in trx/adj number params|
         +----------------------------------------------------------------------*/

        trx_number_low    := REPLACE (p_trx_number_low, '''', '''''');
        trx_number_high   := REPLACE (p_trx_number_high, '''', '''''');
        adj_number_low    := REPLACE (p_adj_number_low, '''', '''''');
        adj_number_high   := REPLACE (p_adj_number_high, '''', '''''');

        /*----------------------------------------------------------------------+
         | Check mandatory parameters     |
         +----------------------------------------------------------------------*/
        IF P_choice IS NULL
        THEN
            arp_standard.fnd_message ('AR_MAND_PARAMETER_NULL',
                                      'PARAM',
                                      'P_choice');
        END IF;

        IF P_open_invoice IS NULL
        THEN
            arp_standard.fnd_message ('AR_MAND_PARAMETER_NULL',
                                      'PARAM',
                                      'P_open_invoice');
        END IF;

        SELECT language_code
          INTO p_base_lang
          FROM fnd_languages
         WHERE installed_flag = 'B';

        SELECT USERENV ('LANG') INTO p_userenv_lang FROM DUAL;

        IF p_userenv_lang IS NULL
        THEN
            language_code   := p_base_lang;
        ELSE
            language_code   := p_userenv_lang;
        END IF;

        /*----------------------------------------------------------------------+
         | Define Tables and aliases           |
         +----------------------------------------------------------------------*/

        table1            :=
               '        AR_ADJUSTMENTS                         COM_ADJ, '
            || cr
            || '        AR_PAYMENT_SCHEDULES                   P, '
            || cr
            || '        RA_CUST_TRX_LINE_GL_DIST               REC, '
            || cr
            || '        RA_CUSTOMER_TRX                        A, '
            || cr
            || '        HZ_CUST_ACCOUNTS                       B, '
            || cr
            || '        RA_TERMS                               T, '
            || cr
            || '        RA_TERMS_LINES                         TL,   '
            || cr
            || '        RA_CUST_TRX_TYPES                      TYPES, '
            || cr
            || '        AR_LOOKUPS                             L_TYPES, '
            || cr
            || '        HZ_PARTIES                     	PARTY, '
            || cr
            ||                                                  -- bug 1630907
               '        HZ_CUST_ACCT_SITES                     A_BILL, '
            || cr
            || '        HZ_PARTY_SITES                         PARTY_SITE, '
            || cr
            || '        HZ_LOCATIONS                           LOC, '
            || cr
            || '        HZ_CUST_SITE_USES                      U_BILL '
            || cr;

        table2            :=
               '        RA_TERMS_LINES                         TL,   '
            || cr
            || '        RA_CUST_TRX_TYPES                      TYPES, '
            || cr
            || '        AR_LOOKUPS                             L_TYPES, '
            || cr
            || '	 HZ_CUST_ACCOUNTS                       B, '
            || cr
            || '        HZ_PARTIES                     	PARTY, '
            || cr
            ||                                                   --bug 1630907
               '        HZ_CUST_SITE_USES                      U_BILL, '
            || cr
            || '        HZ_CUST_ACCT_SITES                     A_BILL, '
            || cr
            || '        HZ_PARTY_SITES                         PARTY_SITE, '
            || cr
            || '        HZ_LOCATIONS                           LOC, '
            || cr
            || '        AR_ADJUSTMENTS                         COM_ADJ, '
            || cr
            || '        RA_CUSTOMER_TRX                        A, '
            || cr
            || '        AR_PAYMENT_SCHEDULES                   P, '
            || cr
            || '        RA_TERMS                               T '
            || cr;



        /*----------------------------------------------------------------------+
         | Determine which clause to use     |
         +----------------------------------------------------------------------*/
        IF P_choice = 'NEW'
        THEN
            choice   := sel_new;
        ELSIF p_choice = 'ADJ'
        THEN
            choice   := sel_adj;
        ELSIF P_choice = 'SEL'
        THEN
            IF trx_number_low IS NOT NULL AND trx_number_high IS NOT NULL
            THEN
                choice   := sel_inv;
            ELSE
                choice   := sel_sel;
            END IF;
        ELSIF P_choice = 'ONE'
        THEN
            BEGIN
                IF P_customer_trx_id IS NULL
                THEN
                    arp_standard.fnd_message ('AR_MAND_PARAMETER_NULL',
                                              'PARAM',
                                              'P_customer_trx_id');
                END IF;

                choice   := sel_one;
            END;
        ELSIF P_choice = 'BATCH'
        THEN
            BEGIN
                IF P_batch_id IS NULL
                THEN
                    arp_standard.fnd_message ('AR_MAND_PARAMETER_NULL',
                                              'PARAM',
                                              'P_batch_id');
                END IF;

                choice   := sel_batch;
            END;
        ELSE
            arp_standard.fnd_message ('AR_RAXINV_INVALID_PARAMETERS',
                                      'PARAM',
                                      'P_choice');
        END IF;

        where1            :=
            where1 || 'A.BILL_TO_CUSTOMER_ID = B.CUST_ACCOUNT_ID';

        /* Join to receivable record */

        where1            :=
            where1 || cr || 'AND REC.CUSTOMER_TRX_ID = A.CUSTOMER_TRX_ID';
        where1            :=
            where1 || cr || 'AND REC.LATEST_REC_FLAG = ''Y'' ';
        where1            :=
            where1 || cr || 'AND REC.ACCOUNT_CLASS   = ''REC'' ';

        /* Join to ar_adjustments for children of commitments. */

        where1            :=
            where1 || cr || 'AND P.PAYMENT_SCHEDULE_ID + DECODE(P.CLASS, ';
        where1            :=
            where1 || cr || '                                   ''INV'', 0,';
        where1            :=
            where1 || cr || '                                        '''')';
        where1            :=
            where1 || cr || '             = COM_ADJ.PAYMENT_SCHEDULE_ID(+)';
        where1            :=
            where1 || cr || 'AND COM_ADJ.SUBSEQUENT_TRX_ID IS NULL';
        where1            :=
            where1 || cr || 'AND ''C''    = COM_ADJ.ADJUSTMENT_TYPE(+)';

        IF P_Choice <> 'ADJ'
        THEN
            where1   := where1 || cr || 'AND A.COMPLETE_FLAG = ''Y''';
        /* bug 762450 :
            if P_Choice <> 'SEL' THEN
              where1 := where1 || cr || 'AND A.PRINTING_OPTION IN (''PRI'', ''REP'')';
            end if;
        */
        END IF;

        where1            :=
            where1 || cr || 'AND A.CUST_TRX_TYPE_ID = TYPES.CUST_TRX_TYPE_ID';
        where1            :=
            where1 || cr || 'AND L_TYPES.LOOKUP_TYPE = ''INV/CM/ADJ''';
        -- bug 762450 :
        -- where1 := where1 || cr || 'AND TYPES.DEFAULT_PRINTING_OPTION = ''PRI''';
        where1            :=
            where1 || cr || 'AND A.PRINTING_OPTION IN (''PRI'', ''REP'')';

        IF p_choice = 'ADJ'
        THEN
            where1   := where1 || cr || 'AND L_TYPES.LOOKUP_CODE = ''ADJ''';
        ELSE
            where1   := where1 || cr || 'AND L_TYPES.LOOKUP_CODE = ';
            where1   :=
                   where1
                || cr
                || 'DECODE( TYPES.TYPE,''DEP'',''INV'', TYPES.TYPE)';
        END IF;

        where1            :=
               where1
            || cr
            || 'AND NVL(P.TERMS_SEQUENCE_NUMBER,nvl(TL.SEQUENCE_NUM,0))=nvl(TL.SEQUENCE_NUM,nvl(p.terms_sequence_number,0))';
        where1            :=
               where1
            || cr
            || 'AND DECODE(P.PAYMENT_SCHEDULE_ID,'''',0, NVL(T.PRINTING_LEAD_DAYS,0))=0';
        where1            :=
            where1 || cr || 'AND A.BILL_TO_SITE_USE_ID = U_BILL.SITE_USE_ID';
        where1            :=
               where1
            || cr
            || 'AND U_BILL.CUST_ACCT_SITE_ID = A_BILL.CUST_ACCT_SITE_ID';
        where1            :=
               where1
            || cr
            || 'AND A_BILL.party_site_id = party_site.party_site_id';
        where1            :=
            where1 || cr || 'AND B.PARTY_ID = PARTY.PARTY_ID';  -- bug 1630907
        where1            :=
            where1 || cr || 'AND loc.location_id = party_site.location_id';

        /*Bug 8448291,chaging p_base_lang  to language_code*/
        IF p_call_from = 'INV'
        THEN
            where1   :=
                   where1
                || cr
                || 'AND NVL(LOC.LANGUAGE,'''
                || language_code
                || ''') = '''
                || language_code
                || '''';
        END IF;

        IF SUBSTR (UPPER (p_open_invoice), 1, 1) = 'Y'
        THEN
            -- Bug Fix 359960, where Credit memos are printed irrespective of whether they are open
            -- or not is not what the documentation says. CM's like all other debit items should be
            -- dependent on the p_open_invoice parameter. Hence reverting back the changes made for
            -- Bug 359960. Changes made for bug 1639132.

            where1   :=
                where1 || cr || 'AND NVL(P.AMOUNT_DUE_REMAINING,0) <> 0';
        END IF;

        IF P_customer_id IS NOT NULL
        THEN
            where1   :=
                where1 || cr || 'AND B.CUST_ACCOUNT_ID = ' || P_customer_id;
        END IF;

        IF P_cust_trx_type_id IS NOT NULL
        THEN
            where1   :=
                   where1
                || cr
                || 'AND A.CUST_TRX_TYPE_ID = '
                || P_cust_trx_type_id;
        END IF;

        IF p_cust_trx_class IS NOT NULL
        THEN
            where1   :=
                   where1
                || cr
                || 'AND TYPES.TYPE = '''
                || p_cust_trx_class
                || '''';
        END IF;

        where1            := where1 || cr || 'AND A.TERM_ID = TL.TERM_ID(+)';
        where1            := where1 || cr || 'AND A.TERM_ID = T.TERM_ID(+)';

        --  where1 := where1 || cr || 'AND T.billing_cycle_id is null ';  -- Commented by BT Dev Team for INC0293103 Invoice not selected for printing.

        IF P_installment_number IS NOT NULL
        THEN
            where1   :=
                where1 || cr || 'AND A.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID';
            where1   :=
                   where1
                || cr
                || 'AND NVL(TL.SEQUENCE_NUM, 1) = '
                || P_installment_number;
        ELSE
            where1   :=
                   where1
                || cr
                || 'AND A.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID(+)';
        END IF;

        IF dates_low IS NOT NULL AND dates_high IS NOT NULL
        THEN
            where1   := where1 || cr || 'AND A.TRX_DATE BETWEEN TO_DATE(''';
            where1   :=
                where1 || TO_CHAR (dates_low, 'DD-MM-YYYY-HH24:MI:SS');
            where1   := where1 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
            where1   := where1 || cr || '                   AND TO_DATE(''';
            where1   :=
                where1 || TO_CHAR (dates_high, 'DD-MM-YYYY-HH24:MI:SS');
            where1   := where1 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
        ELSIF dates_low IS NOT NULL
        THEN
            where1   := where1 || cr || 'AND A.TRX_DATE >= TO_DATE(''';
            where1   :=
                where1 || TO_CHAR (dates_low, 'DD-MM-YYYY-HH24:MI:SS');
            where1   := where1 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
        ELSIF dates_high IS NOT NULL
        THEN
            where1   := where1 || cr || 'AND A.TRX_DATE <= TO_DATE(''';
            where1   :=
                where1 || TO_CHAR (dates_high, 'DD-MM-YYYY-HH24:MI:SS');
            where1   := where1 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
        END IF;

        IF P_customer_class_code IS NOT NULL
        THEN
            where1   :=
                   where1
                || cr
                || 'AND B.CUSTOMER_CLASS_CODE = '''
                || P_customer_class_code
                || '''';
        END IF;

        where2            :=
            where2 || 'A.BILL_TO_CUSTOMER_ID = B.CUST_ACCOUNT_ID';

        /* Join to ar_adjyustments for children of commitments. */
        where2            :=
            where2 || cr || 'AND P.PAYMENT_SCHEDULE_ID + DECODE(P.CLASS, ';
        where2            :=
            where2 || cr || '                                   ''INV'', 0,';
        where2            :=
            where2 || cr || '                                        '''')';
        where2            :=
            where2 || cr || '             = COM_ADJ.PAYMENT_SCHEDULE_ID(+)';

        where2            :=
            where2 || cr || 'AND COM_ADJ.SUBSEQUENT_TRX_ID IS NULL';
        where2            :=
            where2 || cr || 'AND ''C''    = COM_ADJ.ADJUSTMENT_TYPE(+)';

        IF P_Choice <> 'ADJ'
        THEN
            where2   := where2 || cr || 'AND A.COMPLETE_FLAG = ''Y''';
        /*  BUG 762450
            if P_Choice <> 'SEL' THEN
              where2 := where2 || cr || 'AND A.PRINTING_OPTION IN (''PRI'', ''REP'')';
            end if;
        */

        END IF;

        where2            :=
            where2 || cr || 'AND A.CUSTOMER_TRX_ID = P.CUSTOMER_TRX_ID';
        where2            :=
            where2 || cr || 'AND A.CUST_TRX_TYPE_ID = TYPES.CUST_TRX_TYPE_ID';
        where2            :=
            where2 || cr || 'AND L_TYPES.LOOKUP_TYPE = ''INV/CM/ADJ''';

        -- bug 762450
        -- where2 := where2 || cr || 'AND TYPES.DEFAULT_PRINTING_OPTION = ''PRI''';
        where2            :=
            where2 || cr || 'AND A.PRINTING_OPTION IN (''PRI'', ''REP'')';

        IF p_choice = 'ADJ'
        THEN
            where2   := where2 || cr || 'AND L_TYPES.LOOKUP_CODE = ''ADJ''';
        ELSE
            where2   := where2 || cr || 'AND L_TYPES.LOOKUP_CODE = ';
            where2   :=
                   where2
                || cr
                || 'DECODE( TYPES.TYPE,''DEP'',''INV'', TYPES.TYPE)';
        END IF;

        where2            :=
            where2 || cr || 'AND NVL(T.PRINTING_LEAD_DAYS,0) > 0';
        where2            :=
            where2 || cr || 'AND A.BILL_TO_SITE_USE_ID = U_BILL.SITE_USE_ID';
        where2            :=
               where2
            || cr
            || 'AND U_BILL.CUST_ACCT_SITE_ID = A_BILL.CUST_ACCT_SITE_ID';
        where2            :=
               where2
            || cr
            || 'AND A_BILL.PARTY_SITE_ID = PARTY_SITE.PARTY_SITE_ID';
        where2            :=
            where2 || cr || 'AND B.PARTY_ID = PARTY.PARTY_ID';  -- bug 1630907
        where2            :=
            where2 || cr || 'AND LOC.LOCATION_ID = PARTY_SITE.LOCATION_ID';

        /*Bug 8448291,chaging p_base_lang  to language_code*/
        IF p_call_from = 'INV'
        THEN
            where2   :=
                   where2
                || cr
                || 'AND NVL(LOC.LANGUAGE,'''
                || language_code
                || ''') = '''
                || language_code
                || '''';
        END IF;

        where2            :=
               where2
            || cr
            || 'AND NVL(P.TERMS_SEQUENCE_NUMBER,TL.SEQUENCE_NUM)=TL.SEQUENCE_NUM';

        IF SUBSTR (UPPER (p_open_invoice), 1, 1) = 'Y'
        THEN
            -- Bug Fix 359960, where Credit memos are printed irrespective of whether they are open
            -- or not is not what the documentation says. CM's like all other debit items should be
            -- dependent on the p_open_invoice parameter. Hence reverting back the changes made for
            -- Bug 359960. Changes made for bug 1639132.

            where2   :=
                where2 || cr || 'AND NVL(P.AMOUNT_DUE_REMAINING,0) <> 0';
        END IF;

        IF P_customer_id IS NOT NULL
        THEN
            where2   :=
                where2 || cr || 'AND B.CUST_ACCOUNT_ID = ' || P_customer_id;
        END IF;

        IF P_cust_trx_type_id IS NOT NULL
        THEN
            where2   :=
                   where2
                || cr
                || 'AND A.CUST_TRX_TYPE_ID = '
                || P_cust_trx_type_id;
        END IF;

        IF p_cust_trx_class IS NOT NULL
        THEN
            where2   :=
                   where2
                || cr
                || 'AND TYPES.TYPE = '''
                || p_cust_trx_class
                || '''';
        END IF;


        IF P_installment_number IS NOT NULL
        THEN
            where2   := where2 || cr || 'AND T.TERM_ID = A.TERM_ID';
            where2   := where2 || cr || 'AND TL.TERM_ID = T.TERM_ID';
            where2   :=
                   where2
                || cr
                || 'AND P.TERMS_SEQUENCE_NUMBER = '
                || P_installment_number;
        ELSE
            where2   := where2 || cr || 'AND T.TERM_ID = P.TERM_ID';
            where2   := where2 || cr || 'AND TL.TERM_ID(+) = T.TERM_ID';
        END IF;

        --  where2 := where2 || cr || 'AND T.billing_cycle_id is null '; -- Commented by BT Dev Team for INC0293103 Invoice not selected for printing.

        IF dates_low IS NOT NULL AND dates_high IS NOT NULL
        THEN
            where2   := where2 || cr || 'AND P.DUE_DATE BETWEEN TO_DATE(''';
            where2   :=
                where2 || TO_CHAR (dates_low, 'DD-MM-YYYY-HH24:MI:SS');
            where2   := where2 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
            where2   :=
                   where2
                || cr
                || '                       + NVL (T.PRINTING_LEAD_DAYS, 0)';
            where2   := where2 || cr || '                   AND TO_DATE(''';
            where2   :=
                where2 || TO_CHAR (dates_high, 'DD-MM-YYYY-HH24:MI:SS');
            where2   := where2 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
            where2   :=
                   where2
                || cr
                || '                       + NVL (T.PRINTING_LEAD_DAYS, 0)';
        ELSIF dates_low IS NOT NULL
        THEN
            where2   := where2 || cr || 'AND P.DUE_DATE >= TO_DATE(''';
            where2   :=
                where2 || TO_CHAR (dates_low, 'DD-MM-YYYY-HH24:MI:SS');
            where2   :=
                   where2
                || ''',''DD-MM-YYYY-HH24:MI:SS'') + NVL (T.PRINTING_LEAD_DAYS, 0)';
        ELSIF dates_high IS NOT NULL
        THEN
            where2   := where2 || cr || 'AND P.DUE_DATE <= TO_DATE(''';
            where2   :=
                where2 || TO_CHAR (dates_high, 'DD-MM-YYYY-HH24:MI:SS');
            where2   :=
                   where2
                || ''',''DD-MM-YYYY-HH24:MI:SS'') + NVL (T.PRINTING_LEAD_DAYS, 0)';
        END IF;

        IF P_customer_class_code IS NOT NULL
        THEN
            where2   :=
                   where2
                || cr
                || 'AND B.CUSTOMER_CLASS_CODE = '''
                || P_customer_class_code
                || '''';
        END IF;

        IF choice = sel_new
        THEN
            GOTO sel_new_invoice;
        ELSIF choice = sel_inv
        THEN
            GOTO sel_selected_inv;
        ELSIF choice = sel_sel
        THEN
            GOTO sel_selected;
        ELSIF choice = sel_batch
        THEN
            GOTO sel_batch_invoice;
        ELSIF choice = sel_one
        THEN
            GOTO sel_one_invoice;
        ELSIF choice = sel_adj
        THEN
            GOTO sel_adj_adjustments;
        END IF;


       /*----------------------------------------------------------------------+
        | select new invoices       |
        +----------------------------------------------------------------------*/
       <<sel_new_invoice>>
        where1            := where1 || cr || 'AND A.PRINTING_PENDING = ''Y''';
        where1            :=
               where1
            || cr
            || 'AND NVL(TL.SEQUENCE_NUM, 1) > NVL(A.LAST_PRINTED_SEQUENCE_NUM,0)';

        where2            := where2 || cr || 'AND A.PRINTING_PENDING = ''Y''';
        where2            :=
               where2
            || cr
            || 'AND P.TERMS_SEQUENCE_NUMBER > NVL(A.LAST_PRINTED_SEQUENCE_NUM,0)';

       /*----------------------------------------------------------------------+
        | select selected invoices     |
        +----------------------------------------------------------------------*/
       <<sel_selected_inv>>
        where3            := '';

        IF trx_number_low IS NOT NULL AND trx_number_high IS NOT NULL
        THEN
            where3   := where3 || cr || 'AND A.TRX_NUMBER BETWEEN';
            where3   := where3 || ' ''' || trx_number_low || '''';
            where3   := where3 || ' AND ''' || trx_number_high || '''';
        ELSIF trx_number_low IS NOT NULL
        THEN
            where3   :=
                   where3
                || cr
                || 'AND A.TRX_NUMBER >= '''
                || trx_number_low
                || '''';
        ELSIF trx_number_high IS NOT NULL
        THEN
            where3   :=
                   where3
                || cr
                || 'AND A.TRX_NUMBER <= '''
                || trx_number_high
                || '''';
        END IF;

        where1            := where1 || where3;
        where2            := where2 || where3;

        GOTO ok_exit;


       /*----------------------------------------------------------------------+
        | otherwise        |
        +----------------------------------------------------------------------*/
       <<sel_selected>>
        GOTO ok_exit;



       /*----------------------------------------------------------------------+
        | select by batch       |
        +----------------------------------------------------------------------*/
       <<sel_batch_invoice>>
        IF P_batch_id IS NOT NULL
        THEN
            where1   := where1 || cr || 'AND A.BATCH_ID = ' || P_batch_id;
            where2   := where2 || cr || 'AND A.BATCH_ID = ' || P_batch_id;
        END IF;

        GOTO ok_exit;


       /*----------------------------------------------------------------------+
        | select one invoice      |
        +----------------------------------------------------------------------*/
       <<sel_one_invoice>>
        IF P_customer_trx_id IS NOT NULL
        THEN
            where1   :=
                   where1
                || cr
                || 'AND A.CUSTOMER_TRX_ID = '
                || P_customer_trx_id;
            where2   :=
                   where2
                || cr
                || 'AND A.CUSTOMER_TRX_ID = '
                || P_customer_trx_id;
        END IF;

        GOTO ok_exit;


       /*----------------------------------------------------------------------+
        | select adjustments      |
        +----------------------------------------------------------------------*/
       <<sel_adj_adjustments>>
        table1            :=
            table1 || ',       AR_ADJUSTMENTS            ADJ' || cr;
        table2            :=
            table2 || ',       AR_ADJUSTMENTS            ADJ' || cr;

        where3            :=
            cr || 'and a.customer_trx_id = adj.customer_trx_id ';

        IF adj_number_low IS NOT NULL OR adj_number_high IS NOT NULL
        THEN
            BEGIN
                IF adj_number_low IS NOT NULL AND adj_number_high IS NOT NULL
                THEN
                    where3   :=
                        where3 || cr || 'AND ADJ.ADJUSTMENT_NUMBER BETWEEN';
                    where3   := where3 || ' ''' || adj_number_low || '''';
                    where3   :=
                        where3 || ' AND ''' || adj_number_high || '''';
                ELSIF adj_number_low IS NOT NULL
                THEN
                    where3   :=
                           where3
                        || cr
                        || 'AND ADJ.ADJUSTMENT_NUMBER >= '''
                        || adj_number_low
                        || '''';
                ELSIF adj_number_high IS NOT NULL
                THEN
                    where3   :=
                           where3
                        || cr
                        || 'AND ADJ.ADJUSTMENT_NUMBER <= '''
                        || adj_number_high
                        || '''';
                END IF;
            END;
        END IF;

        IF adj_dates_low IS NOT NULL OR adj_dates_high IS NOT NULL
        THEN
            BEGIN
                IF adj_dates_low IS NOT NULL AND adj_dates_high IS NOT NULL
                THEN
                    where3   :=
                           where3
                        || cr
                        || 'AND ADJ.APPLY_DATE BETWEEN TO_DATE(''';
                    where3   :=
                           where3
                        || TO_CHAR (adj_dates_low, 'DD-MM-YYYY-HH24:MI:SS');
                    where3   := where3 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
                    where3   :=
                        where3 || cr || '                   AND TO_DATE(''';
                    where3   :=
                           where3
                        || TO_CHAR (adj_dates_high, 'DD-MM-YYYY-HH24:MI:SS');
                    where3   := where3 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
                ELSIF adj_dates_low IS NOT NULL
                THEN
                    where3   :=
                        where3 || cr || 'AND ADJ.APPLY_DATE >= TO_DATE(''';
                    where3   :=
                           where3
                        || TO_CHAR (adj_dates_low, 'DD-MM-YYYY-HH24:MI:SS');
                    where3   := where3 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
                ELSIF adj_dates_high IS NOT NULL
                THEN
                    where3   :=
                        where3 || cr || 'AND ADJ.APPLY_DATE <= TO_DATE(''';
                    where3   :=
                           where3
                        || TO_CHAR (adj_dates_high, 'DD-MM-YYYY-HH24:MI:SS');
                    where3   := where3 || ''',''DD-MM-YYYY-HH24:MI:SS'')';
                END IF;
            END;
        END IF;

        where3            := where3 || cr || 'AND ADJ.STATUS = ''A''';

        where1            := where1 || where3;
        where2            := where2 || where3;


        GOTO sel_selected_inv;


       /*----------------------------------------------------------------------+
        | exit successfully       |
        +----------------------------------------------------------------------*/
       <<ok_exit>>
        P_where1          := where1;
        P_where2          := where2;
        p_table1          := table1;
        p_table2          := table2;
    END;                             /* end of procedure build_where_clause */
END XXDO_AR_ARP_TRX_SELECT_CONTROL;
/
