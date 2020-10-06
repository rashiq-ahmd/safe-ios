//
//  TransactionDetailsView.swift
//  Multisig
//
//  Created by Moaaz on 5/29/20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import SwiftUI

struct TransactionDetailsView: View {
    @ObservedObject
    var model: TransactionDetailsViewModel

    init(transaction: TransactionViewModel) {
        model = TransactionDetailsViewModel(transaction: transaction)
    }

    var body: some View {
        ZStack {
            LoadableView(TransactionDetailsBodyView(model: model), reloadsOnAppOpen: false)
        }
        .navigationBarTitle("Transaction Details", displayMode: .inline)
        .onAppear {
            self.trackEvent(.transactionsDetails)
        }
    }
}

struct TransactionDetailsBodyView: Loadable {
    @ObservedObject
    var model: TransactionDetailsViewModel

    var transaction: TransactionViewModel {
        model.transactionDetails
    }

    var displayConfirmations: Bool {
        guard let transferTransaction = transaction as? TransferTransactionViewModel else {
            return true
        }

        return transferTransaction.isOutgoing
    }

    private var data: (length: UInt256, data: String)? {
        guard let customTransaction = transaction as? CustomTransactionViewModel,
              let data = customTransaction.data else {
            return nil
        }

        return (length: customTransaction.dataLength, data: data)
    }

    private let padding: CGFloat = 11

    var body: some View {
        List {
            if transaction as? CreationTransactionViewModel == nil {
                transactionDetailsBodyView
            } else {
                CreationTransactionBodyView(transaction: transaction as! CreationTransactionViewModel)
            }
        }
        .navigationBarTitle("Transaction Details", displayMode: .inline)
        .onAppear {
            self.trackEvent(.transactionsDetails)
        }
    }

    var transactionDetailsBodyView: some View {
        Group {
            TransactionHeaderView(transaction: transaction)

//            if data != nil {
//                VStack (alignment: .leading) {
//                    Text("Data").headline()
//                    ExpandableButton(title: "\(data!.length) Bytes", value: data!.data)
//                }.padding(.vertical, 11)
//            }

            TransactionStatusTypeView(transaction: transaction)
//            if displayConfirmations {
//                TransactionConfirmationsView(transaction: transaction, safe: model.safe!).padding(.vertical, padding)
//            }

//            if transaction.formattedCreatedDate != nil {
//                KeyValueRow("Created:", value: transaction.formattedCreatedDate!, enableCopy: false, color: .gnoDarkGrey).padding(.vertical, padding)
//            }
//
//            if transaction.formattedExecutedDate != nil {
//                KeyValueRow("Executed:", value: transaction.formattedExecutedDate!, enableCopy: false, color: .gnoDarkGrey).padding(.vertical, padding)
//            }
//
//            if transaction.hasAdvancedDetails {
//                NavigationLink(destination: AdvancedTransactionDetailsView(transaction: transaction)) {
//                    Text("Advanced").body()
//                }
//                .frame(height: 48)
//            }
        }
    }
}
