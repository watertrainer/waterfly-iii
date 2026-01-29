import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/pages/transaction.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/timezonehandler.dart';

final Logger log = Logger("Pages.Bookmarks");

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  final Logger log = Logger("Pages.Bookmarks.Page");

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavPageElements>().appBarTitle = Text(
        S.of(context).bookmarksPageTitle,
      );
      context.read<NavPageElements>().appBarActions = null;
      context.read<NavPageElements>().fab = null;
    });
  }

  Future<void> _sendBookmarkedTransaction(
    BuildContext context,
    TransactionRead transaction,
  ) async {
    final FireflyIii api = context.read<FireflyService>().api;
    final TimeZoneHandler tzHandler = context.read<FireflyService>().tzHandler;
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final S l10n = S.of(context);

    try {
      // Get the current date/time
      final DateTime now = tzHandler.newTXTime().toLocal();

      // Create the transaction with current date
      final List<TransactionSplitStore> splits = <TransactionSplitStore>[];
      for (final TransactionSplit tx in transaction.attributes.transactions) {
        splits.add(
          TransactionSplitStore(
            type: tx.type,
            date: now,
            amount: tx.amount,
            description: tx.description,
            currencyId: tx.currencyId,
            currencyCode: tx.currencyCode,
            foreignAmount: tx.foreignAmount,
            foreignCurrencyId: tx.foreignCurrencyId,
            budgetId: tx.budgetId,
            categoryId: tx.categoryId,
            categoryName: tx.categoryName,
            sourceId: tx.sourceId,
            sourceName: tx.sourceName,
            destinationId: tx.destinationId,
            destinationName: tx.destinationName,
            reconciled: false,
            notes: tx.notes,
            tags: tx.tags,
            billId: tx.billId,
          ),
        );
      }

      final TransactionStore newTx = TransactionStore(
        groupTitle: transaction.attributes.groupTitle,
        transactions: splits,
      );

      final Response<TransactionSingle> response =
          await api.v1TransactionsPost(body: newTx);
      apiThrowErrorIfEmpty(response, context.mounted ? context : null);

      if (context.mounted) {
        // Refresh stock
        context.read<FireflyService>().transStock?.clear();
        msg.showSnackBar(
          SnackBar(
            content: Text(l10n.transactionBookmarkSent),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      log.severe("Error sending bookmarked transaction", e, stackTrace);
      if (context.mounted) {
        msg.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBookmark(
    BuildContext context,
    String transactionId,
  ) async {
    final S l10n = S.of(context);
    final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
    final SettingsProvider settings = context.read<SettingsProvider>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.bookmark_remove),
        title: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
        content: Text(l10n.bookmarksDeleteConfirm),
        actions: <Widget>[
          TextButton(
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await settings.removeBookmarkedTransactionById(transactionId);
      msg.showSnackBar(
        SnackBar(
          content: Text(l10n.transactionBookmarkRemoved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");

    final List<String> bookmarks =
        context.watch<SettingsProvider>().bookmarkedTransactions;

    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.bookmark_border, size: 64),
            const SizedBox(height: 16),
            Text(
              S.of(context).bookmarksPageEmpty,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: bookmarks.length,
      itemBuilder: (BuildContext context, int index) {
        try {
          final TransactionRead transaction = TransactionRead.fromJson(
            jsonDecode(bookmarks[index]),
          );
          return _buildBookmarkCard(context, transaction);
        } catch (e) {
          log.warning("Failed to parse bookmark at index $index", e);
          // Remove corrupted bookmark
          context.read<SettingsProvider>().removeBookmarkedTransaction(index);
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildBookmarkCard(
    BuildContext context,
    TransactionRead transaction,
  ) {
    final List<TransactionSplit> transactions =
        transaction.attributes.transactions;
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final TransactionSplit firstTx = transactions.first;

    // Title
    String title;
    if (transaction.attributes.groupTitle?.isNotEmpty ?? false) {
      title = transaction.attributes.groupTitle!;
    } else {
      title = firstTx.description;
    }

    // Amount
    double amount = 0.0;
    for (final TransactionSplit tx in transactions) {
      amount += double.tryParse(tx.amount) ?? 0.0;
    }

    // Currency
    final CurrencyRead currency = CurrencyRead(
      id: firstTx.currencyId ?? "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: firstTx.currencyCode ?? "",
        name: firstTx.currencyName ?? "",
        symbol: firstTx.currencySymbol ?? "",
        decimalPlaces: firstTx.currencyDecimalPlaces,
      ),
    );

    // Category
    String category = "";
    for (final TransactionSplit tx in transactions) {
      if (tx.categoryName?.isNotEmpty ?? false) {
        if (category.isEmpty) {
          category = tx.categoryName!;
        } else {
          category = S.of(context).generalMultiple;
          break;
        }
      }
    }

    // Account names
    final String sourceName = firstTx.sourceName ?? "";
    final String destinationName = firstTx.destinationName ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          // Open transaction page for editing/viewing
          Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (BuildContext context) => TransactionPage(
                transaction: transaction,
                clone: true,
              ),
            ),
          );
        },
        onLongPress: () async {
          unawaited(HapticFeedback.vibrate());
          final Size screenSize = MediaQuery.of(context).size;
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset offset = renderBox.localToGlobal(Offset.zero);

          final Function? func = await showMenu<Function>(
            context: context,
            position: RelativeRect.fromLTRB(
              offset.dx + renderBox.size.width / 2,
              offset.dy,
              screenSize.width - offset.dx - renderBox.size.width / 2,
              screenSize.height - offset.dy,
            ),
            items: <PopupMenuEntry<Function>>[
              PopupMenuItem<Function>(
                value: () => _sendBookmarkedTransaction(
                  context,
                  transaction,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.send),
                    const SizedBox(width: 12),
                    Text(S.of(context).transactionBookmarkSendNow),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<Function>(
                value: () => _deleteBookmark(context, transaction.id),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.bookmark_remove),
                    const SizedBox(width: 12),
                    Text(MaterialLocalizations.of(context).deleteButtonTooltip),
                  ],
                ),
              ),
            ],
            clipBehavior: Clip.hardEdge,
          );
          if (func != null && context.mounted) {
            func();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                foregroundColor: Colors.white,
                backgroundColor: firstTx.type.color,
                child: Icon(firstTx.type.icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstTx.type == TransactionTypeProperty.withdrawal ||
                              firstTx.type == TransactionTypeProperty.transfer
                          ? destinationName
                          : sourceName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category.isNotEmpty)
                      Text(
                        category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    currency.fmt(amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: firstTx.type.color,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.send),
                        tooltip: S.of(context).transactionBookmarkSendNow,
                        onPressed: () => _sendBookmarkedTransaction(
                          context,
                          transaction,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_remove),
                        tooltip:
                            MaterialLocalizations.of(context).deleteButtonTooltip,
                        onPressed: () => _deleteBookmark(context, transaction.id),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
