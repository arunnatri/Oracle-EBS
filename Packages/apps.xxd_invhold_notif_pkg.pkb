--
-- XXD_INVHOLD_NOTIF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INVHOLD_NOTIF_PKG"
AS
    /*******************************************************************************
      * Program Name : StartProcess
      * Language     : PL/SQL
      * Description  : This procedure will start the hold notification workflow.
      *
      * History      :
      *
      * WHO            WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * Krishna H      1.0                                              10-May-2015
      *Meenakshi       1.1  To Display Invoice Amount                   04-Nov-2015
      *******************************************************************************/
    PROCEDURE StartProcess (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_hold_id IN NUMBER
                            , p_invoice_id IN NUMBER)
    IS
        l_ItemType          VARCHAR2 (30) := 'XXDHLDN';
        l_WorkflowProcess   VARCHAR2 (30) := 'XXD_HOLD_MAIN';
        l_item_Key          VARCHAR2 (30);
        ItemUserKey         VARCHAR2 (80) := 'RequisitionDesc';
        item_seq            NUMBER;
        l_inv_number        VARCHAR2 (50);
        l_supplier_name     VARCHAR2 (100);
        l_org_id            NUMBER;
        l_inv_amt           NUMBER;          --Added to display invoice amount
    BEGIN
        SELECT XXD_INV_HOLD_NOTIF_S.NEXTVAL INTO item_seq FROM DUAL;


        SELECT i.org_id, s.vendor_name, i.invoice_num,
               i.INVOICE_AMOUNT             -- added to display invoice amount
          INTO l_org_id, l_supplier_name, l_inv_number, l_inv_amt
          FROM ap_invoices_all i, ap_suppliers s
         WHERE i.vendor_id = s.vendor_id AND i.invoice_id = p_invoice_id;


        l_item_Key   := p_hold_id || '-' || item_seq;

        wf_engine.CreateProcess (itemtype   => l_itemType,
                                 itemkey    => l_item_Key,
                                 process    => l_WorkflowProcess);

        wf_engine.SetItemUserKey (itemtype   => l_itemType,
                                  itemkey    => l_item_Key,
                                  userkey    => l_item_Key);

        wf_engine.SetItemAttrText (itemtype => l_itemType, itemkey => l_item_Key, aname => 'INVOICE_NUMBER'
                                   , avalue => l_inv_number);

        --fnd_file.put_line (fnd_file.log, 'INVOICE_NUMBER :'||l_inv_number|| CHR (13)|| CHR (10));

        wf_engine.SetItemAttrText (itemtype => l_itemType, itemkey => l_item_Key, aname => 'INVOICE_SUPPLIER_NAME'
                                   , avalue => l_supplier_name);

        --fnd_file.put_line (fnd_file.log, 'INVOICE_SUPPLIER_NAME :'||l_supplier_name|| CHR (13)|| CHR (10));

        wf_engine.SetItemAttrNumber (itemtype => l_itemType, itemkey => l_item_Key, aname => 'ORG_ID'
                                     , avalue => l_org_id);

        --fnd_file.put_line (fnd_file.log, 'ORG_ID :'||l_org_id|| CHR (13)|| CHR (10));

        wf_engine.SetItemAttrNumber (itemtype => l_itemType, itemkey => l_item_Key, aname => 'HOLD_ID'
                                     , avalue => p_hold_id);

        --fnd_file.put_line (fnd_file.log, 'HOLD_ID :'||p_hold_id|| CHR (13)|| CHR (10));

        wf_engine.SetItemAttrNumber (itemtype => l_itemType, itemkey => l_item_Key, aname => 'INVOICE_ID'
                                     , avalue => p_invoice_id);


        wf_engine.SetItemAttrNumber (itemtype => l_itemType, -- Added to display invoice amount
                                                             itemkey => l_item_Key, aname => 'INVOICE_TOTAL'
                                     , avalue => l_inv_amt);

        --fnd_file.put_line (fnd_file.log, 'INVOICE_ID :'||p_invoice_id|| CHR (13)|| CHR (10));

        wf_engine.SetItemOwner (itemtype   => l_itemType,
                                itemkey    => l_item_Key,
                                owner      => 'ProcessOwner');

        wf_engine.StartProcess (itemtype => l_itemType, itemkey => l_item_Key);
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.context ('XXDHLDN', 'XXD_HOLD_MAIN', l_item_Key,
                             p_hold_id);
            RAISE;
    END StartProcess;
END XXD_INVHOLD_NOTIF_PKG;
/
