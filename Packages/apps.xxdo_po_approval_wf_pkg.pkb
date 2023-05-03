--
-- XXDO_PO_APPROVAL_WF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_PO_APPROVAL_WF_PKG
/**********************************************************************************************************

    File Name    : XXDO_PO_APPROVAL_WF_PKG

    Created On   : 15-DEC-2014

    Created By   : BT Technology Team

    Purpose      : This  package is to provide individual functions and procedures for PO Print.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
  1.0              BT Technology Team          15-Dec-2014               Base Version
    **********************************************************************************************************/
AS
    PROCEDURE IS_TRADE_PO (itemtype    IN            VARCHAR2,
                           itemkey     IN            VARCHAR2,
                           actid       IN            NUMBER,
                           funcmode    IN            VARCHAR2,
                           resultout      OUT NOCOPY VARCHAR2)
    IS
        l_progress           VARCHAR2 (300);
        l_po_header_id       PO_HEADERS_ALL.PO_HEADER_ID%TYPE;
        l_vendor_type_code   VARCHAR2 (100);
        l_category           VARCHAR2 (40);
        l_resultout          VARCHAR2 (1);
    BEGIN
        l_progress       := 'XXDO_PO_APPROVAL_WF_PKG.IS_NON_TRADE_PO: 01';



        l_po_header_id   :=
            PO_WF_UTIL_PKG.GetItemAttrText (itemtype   => itemtype,
                                            itemkey    => itemkey,
                                            aname      => 'DOCUMENT_ID');



        l_category       := GET_PO_CATEGORY (l_po_header_id);



        SELECT ap.vendor_type_lookup_code
          INTO l_vendor_type_code
          FROM AP_SUPPLIERS ap, po_headers_all pha
         WHERE     ap.vendor_id = pha.vendor_id
               AND pha.po_header_id = l_po_header_id;



        IF     UPPER (l_vendor_type_code) = 'MANUFACTURER'
           AND UPPER (l_category) = 'TRADE'
        THEN
            l_resultout   := 'Y';
        ELSE
            l_resultout   := 'N';
        END IF;

        resultout        := wf_engine.eng_completed || ':' || l_resultout;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_resultout   := 'Y';
            resultout     := wf_engine.eng_completed || ':' || l_resultout;
    END IS_TRADE_PO;

    FUNCTION HEADER_ATTACHMENT (p_po_header_id NUMBER)
        RETURN CLOB
    IS
        l_attachment   CLOB := EMPTY_CLOB ();

        CURSOR c_header_attachment (po_header_id NUMBER)
        IS
            SELECT CASE
                       WHEN fdd.NAME = 'SHORT_TEXT'
                       THEN
                           (SELECT short_text
                              FROM fnd_documents_short_text
                             WHERE media_id = fd.media_id)
                       WHEN fdd.NAME = 'LONG_TEXT'
                       THEN
                           (SELECT TO_CHAR (long_text)
                              FROM fnd_documents_long_text
                             WHERE media_id = fd.media_id)
                       ELSE
                           NULL
                   END notes
              FROM fnd_attached_documents fad, FND_DOCUMENT_CATEGORIES_VL fdct, FND_DOCUMENTS_VL fd,
                   FND_DOCUMENT_DATATYPES_VL fdd
             WHERE     fad.category_id = fdct.category_id
                   AND fdct.user_name = 'To Supplier'
                   AND fad.pk1_value = po_header_id
                   AND fad.ENTITY_NAME = 'PO_HEADERS'
                   AND fad.document_id = fd.document_id
                   AND fd.datatype_id = fdd.datatype_id;
    BEGIN
        DBMS_LOB.createtemporary (l_attachment, TRUE, DBMS_LOB.session);

        FOR r_header_attachment IN c_header_attachment (p_po_header_id)
        LOOP
            DBMS_LOB.writeappend (
                l_attachment,
                LENGTH (r_header_attachment.notes || CHR (10)),
                r_header_attachment.notes || CHR (10));
        END LOOP;


        RETURN l_attachment;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END HEADER_ATTACHMENT;

    FUNCTION LINE_ATTACHMENT (p_po_line_id NUMBER, p_note_to_vendor VARCHAR2)
        RETURN CLOB
    IS
        l_attachment   CLOB := EMPTY_CLOB;

        CURSOR c_line_attachment (po_line_id NUMBER)
        IS
            SELECT CASE
                       WHEN fdd.NAME = 'SHORT_TEXT'
                       THEN
                           (SELECT short_text
                              FROM fnd_documents_short_text
                             WHERE media_id = fd.media_id)
                       WHEN fdd.NAME = 'LONG_TEXT'
                       THEN
                           (SELECT TO_CHAR (long_text)
                              FROM fnd_documents_long_text
                             WHERE media_id = fd.media_id)
                       ELSE
                           NULL
                   END notes
              FROM fnd_attached_documents fad, FND_DOCUMENT_CATEGORIES_VL fdct, FND_DOCUMENTS_VL fd,
                   FND_DOCUMENT_DATATYPES_VL fdd
             WHERE     fad.category_id = fdct.category_id
                   AND fdct.user_name = 'To Supplier'
                   AND fad.pk1_value = p_po_line_id
                   AND fad.ENTITY_NAME = 'PO_LINES'
                   AND fad.document_id = fd.document_id
                   AND fd.datatype_id = fdd.datatype_id;
    BEGIN
        DBMS_LOB.createtemporary (l_attachment, TRUE, DBMS_LOB.session);

        DBMS_LOB.writeappend (l_attachment,
                              LENGTH (p_note_to_vendor || CHR (10)),
                              p_note_to_vendor || CHR (10));


        FOR r_line_attachment IN c_line_attachment (p_po_line_id)
        LOOP
            DBMS_LOB.writeappend (
                l_attachment,
                LENGTH (r_line_attachment.notes || CHR (10)),
                r_line_attachment.notes || CHR (10));
        END LOOP;

        RETURN l_attachment;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END LINE_ATTACHMENT;

    FUNCTION GET_PO_CATEGORY (p_po_header_id NUMBER)
        RETURN VARCHAR2
    IS
        l_category   VARCHAR2 (40);
    BEGIN
        SELECT MC.segment1
          INTO l_category
          FROM (SELECT MIN (PL1.po_line_id) po_line_id
                  FROM po_lines_all PL1
                 WHERE     PL1.po_header_id = p_po_header_id
                       AND NVL (cancel_flag, 'N') <> 'Y') PLA,
               po_lines_all PL,
               mtl_categories MC
         WHERE     PLA.po_line_id = PL.po_line_id
               AND PL.category_id = MC.category_id;


        RETURN l_category;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END GET_PO_CATEGORY;

    FUNCTION GET_TERMS_N_CONDITIONS (p_po_ship_to_id   NUMBER,
                                     p_po_org_id       NUMBER)
        RETURN CLOB
    IS
        l_inv_org_id   NUMBER;
        l_sob_id       NUMBER;
        l_tnC          CLOB := EMPTY_CLOB ();
        l_inv_TnC      CLOB := EMPTY_CLOB ();
        l_sob_TnC      CLOB := EMPTY_CLOB ();
    BEGIN
        DBMS_LOB.createtemporary (l_tnC, TRUE, DBMS_LOB.session);
        DBMS_LOB.createtemporary (l_inv_TnC, TRUE, DBMS_LOB.session);
        DBMS_LOB.createtemporary (l_inv_TnC, TRUE, DBMS_LOB.session);

        BEGIN
            SELECT inventory_organization_id
              INTO l_inv_org_id
              FROM HR_LOCATIONS_ALL_VL
             WHERE location_id = p_po_ship_to_id;


            BEGIN
                SELECT fdlt.long_text
                  INTO l_inv_TnC
                  FROM FND_DOCUMENT_CATEGORIES_VL fdct, FND_DOCUMENTS_VL fd, FND_DOCUMENT_DATATYPES_VL fdd,
                       fnd_documents_long_text fdlt
                 WHERE     fd.category_id = fdct.category_id
                       AND fdct.user_name IN
                               ('????', 'To Supplier', '????')
                       AND fd.datatype_id = fdd.datatype_id
                       AND fdd.NAME = 'LONG_TEXT'
                       AND fd.SECURITY_TYPE = 1
                       AND fd.SECURITY_ID = l_inv_org_id
                       AND fdlt.media_id = fd.media_id
                       AND fd.usage_type = 'S'
                       AND SYSDATE BETWEEN NVL (fd.START_DATE_ACTIVE,
                                                SYSDATE)
                                       AND NVL (fd.END_DATE_ACTIVE, SYSDATE);

                DBMS_LOB.writeappend (l_TnC, LENGTH (l_inv_TnC), l_inv_TnC);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    SELECT set_of_books_id
                      INTO l_sob_id
                      FROM hr_operating_units
                     WHERE organization_id = p_po_org_id;


                    SELECT fdlt.long_text
                      INTO l_sob_TnC
                      FROM FND_DOCUMENT_CATEGORIES_VL fdct, FND_DOCUMENTS_VL fd, FND_DOCUMENT_DATATYPES_VL fdd,
                           fnd_documents_long_text fdlt
                     WHERE     fd.category_id = fdct.category_id
                           AND fdct.user_name IN
                                   ('????', 'To Supplier', '????')
                           AND fd.datatype_id = fdd.datatype_id
                           AND fdd.NAME = 'LONG_TEXT'
                           AND fd.SECURITY_TYPE = 2
                           AND fd.SECURITY_ID = l_sob_id
                           AND fdlt.media_id = fd.media_id
                           AND fd.usage_type = 'S'
                           AND SYSDATE BETWEEN NVL (fd.START_DATE_ACTIVE,
                                                    SYSDATE)
                                           AND NVL (fd.END_DATE_ACTIVE,
                                                    SYSDATE);

                    DBMS_LOB.writeappend (l_TnC,
                                          LENGTH (l_sob_TnC),
                                          l_sob_TnC);
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                SELECT set_of_books_id
                  INTO l_sob_id
                  FROM hr_operating_units
                 WHERE organization_id = p_po_org_id;


                SELECT fdlt.long_text
                  INTO l_sob_TnC
                  FROM FND_DOCUMENT_CATEGORIES_VL fdct, FND_DOCUMENTS_VL fd, FND_DOCUMENT_DATATYPES_VL fdd,
                       fnd_documents_long_text fdlt
                 WHERE     fd.category_id = fdct.category_id
                       AND fdct.user_name IN
                               ('????', 'To Supplier', '????')
                       AND fd.datatype_id = fdd.datatype_id
                       AND fdd.NAME = 'LONG_TEXT'
                       AND fd.SECURITY_TYPE = 2
                       AND fd.SECURITY_ID = l_sob_id
                       AND fdlt.media_id = fd.media_id
                       AND fd.usage_type = 'S'
                       AND SYSDATE BETWEEN NVL (fd.START_DATE_ACTIVE,
                                                SYSDATE)
                                       AND NVL (fd.END_DATE_ACTIVE, SYSDATE);

                DBMS_LOB.writeappend (l_TnC, LENGTH (l_sob_TnC), l_sob_TnC);
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN l_TnC;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END GET_TERMS_N_CONDITIONS;
END XXDO_PO_APPROVAL_WF_PKG;
/
