// Order detail: summary, receiver card, slip/proof images, status
// timeline, admin action panel and owner cancel — mirrors
// renderOrderDetail() in js/app.js.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../quote.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.state,
    required this.orderId,
    super.key,
  });

  final AppState state;
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Order?> _future;
  final _note = TextEditingController();
  PickedImage? _proof;
  bool _busy = false;
  String? _loadedOrderId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<Order?> _load() => widget.state.store.getOrder(widget.orderId);

  void _reload() {
    setState(() {
      _proof = null;
      _loadedOrderId = null;
      _future = _load();
    });
  }

  bool _canView(Order order) {
    if (widget.state.isAdmin) return true;
    final user = widget.state.user;
    return user != null && order.userId == user.id;
  }

  bool _canCancel(Order order) {
    final user = widget.state.user;
    return !widget.state.isAdmin &&
        order.status == 'pending' &&
        user != null &&
        order.userId == user.id;
  }

  Future<void> _cancel(Order order) async {
    final user = widget.state.user;
    if (user == null) return;
    final ok = await showConfirm(
      context,
      title: s('cancelOrder'),
      body: s('cancelConfirm'),
      confirmLabel: s('cancelOrder'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.state.store.cancelOrder(order.id, user.id);
      if (!mounted) return;
      showSnack(context, s('cancelledOk'));
      _reload();
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    }
  }

  Future<void> _markReviewing(Order order) async {
    setState(() => _busy = true);
    try {
      await widget.state.store.updateOrderStatus(
        order.id,
        'reviewing',
        adminNote: _note.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, s('orderUpdated'));
      _reload();
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Order order) async {
    // A freshly picked proof is REQUIRED to complete, like the website.
    if (_proof == null) {
      showSnack(context, s('proofRequired'), isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      // Proof goes into the ORDER OWNER's folder so the customer can
      // view it (storage SELECT policy: own folder or admin).
      final proofPath = await widget.state.store.uploadFile(
        'proofs',
        order.userId,
        _proof!.bytes,
        _proof!.fileName,
      );
      await widget.state.store.updateOrderStatus(
        order.id,
        'completed',
        adminNote: _note.text.trim(),
        proofPath: proofPath,
      );
      if (!mounted) return;
      showSnack(context, s('orderUpdated'));
      _reload();
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(Order order) async {
    setState(() => _busy = true);
    try {
      await widget.state.store.updateOrderStatus(
        order.id,
        'rejected',
        adminNote: _note.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, s('orderUpdated'));
      _reload();
    } catch (_) {
      if (mounted) showSnack(context, s('errorGeneric'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickProof() async {
    final picked = await pickSlipImage(context);
    if (picked != null && mounted) setState(() => _proof = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s('ordersTitle'))),
      body: FutureBuilder<Order?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final order = snapshot.data;
          if (snapshot.hasError || order == null || !_canView(order)) {
            return SingleChildScrollView(
              child: ErrorView(
                message: s('orderNotFound'),
                onRetry: _reload,
              ),
            );
          }
          // Prefill the admin note once per loaded order.
          if (_loadedOrderId != order.id) {
            _loadedOrderId = order.id;
            _note.text = order.adminNote;
          }
          final showAdminPanel = widget.state.isAdmin &&
              (order.status == 'pending' || order.status == 'reviewing');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNo,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          StatusPill(order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      KvRow(
                        label: s('date'),
                        value: fmtDateTime(order.createdAt),
                      ),
                      KvRow(
                        label: s('directionLabel'),
                        value: orderDirectionLabel(order.direction),
                      ),
                      KvRow(
                        label: s('sendAmount'),
                        value: fmtMoney(
                          order.sendAmount,
                          order.sendCurrency,
                        ),
                      ),
                      KvRow(
                        label: s('rate'),
                        value: fmtNum(order.rate, 2),
                      ),
                      KvRow(
                        label: s('fee'),
                        value: fmtMoney(order.fee, order.receiveCurrency),
                      ),
                      KvRow(
                        label: s('receiveAmount'),
                        value: fmtMoney(
                          order.receiveAmount,
                          order.receiveCurrency,
                        ),
                      ),
                      if (order.adminNote.isNotEmpty)
                        KvRow(label: s('adminNote'), value: order.adminNote),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardTitle(s('receiver')),
                      const SizedBox(height: 8),
                      KvRow(
                        label: s('receiveMethod'),
                        value: order.receiveMethod,
                      ),
                      KvRow(
                        label: s('receiverName'),
                        value: order.receiverName,
                      ),
                      KvRow(
                        label: s('receiverAccount'),
                        value: order.receiverAccount,
                      ),
                      KvRow(
                        label: s('receiverPhone'),
                        value: order.receiverPhone,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => copyText(
                          context,
                          [
                            order.receiveMethod,
                            order.receiverName,
                            order.receiverAccount,
                            order.receiverPhone,
                          ].where((v) => v.isNotEmpty).join('\n'),
                        ),
                        child: Text(s('copyReceiver')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardTitle(s('slip')),
                      const SizedBox(height: 8),
                      if (order.slipTxnId.isNotEmpty)
                        KvRow(label: s('slipTxn'), value: order.slipTxnId),
                      if (order.slipPath != null)
                        SlipImage(
                          store: widget.state.store,
                          bucket: 'slips',
                          path: order.slipPath!,
                        )
                      else
                        Text(
                          s('noSlip'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardTitle(s('proof')),
                      const SizedBox(height: 8),
                      if (order.proofPath != null)
                        SlipImage(
                          store: widget.state.store,
                          bucket: 'proofs',
                          path: order.proofPath!,
                        )
                      else
                        Text(
                          s('noProof'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardTitle(s('timelineTitle')),
                      const SizedBox(height: 8),
                      _Timeline(order: order),
                    ],
                  ),
                ),
                if (showAdminPanel) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CardTitle(s('adminTitle')),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _note,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: s('adminNote'),
                            hintText: s('rejectReasonPh'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (order.status == 'pending')
                          OutlinedButton(
                            onPressed: _busy ? null : () => _markReviewing(order),
                            child: Text(s('markReviewing')),
                          ),
                        if (order.status == 'pending')
                          const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickProof,
                          icon: const Icon(Icons.upload_outlined),
                          label: Text(
                            _proof == null
                                ? s('proofUpload')
                                : _proof!.fileName,
                          ),
                        ),
                        if (_proof != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              Uint8List.fromList(_proof!.bytes),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          s('completeConfirm'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blueDark,
                          ),
                          onPressed: _busy ? null : () => _complete(order),
                          child: Text(s('completeOrder')),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                          ),
                          onPressed: _busy ? null : () => _reject(order),
                          child: Text(s('rejectOrder')),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_canCancel(order)) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                    ),
                    onPressed: () => _cancel(order),
                    child: Text(s('cancelOrder')),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Status timeline — mirrors timelineHtml() in js/app.js.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final steps = <({String label, DateTime? time, bool bad})>[
      (label: s('timelineCreated'), time: order.createdAt, bad: false),
    ];
    if (order.status == 'reviewing' || order.status == 'completed') {
      steps.add(
        (
          label: s('timelineReviewing'),
          time: order.updatedAt,
          bad: false,
        ),
      );
    }
    if (order.status == 'completed') {
      steps.add(
        (
          label: s('timelineCompleted'),
          time: order.completedAt ?? order.updatedAt,
          bad: false,
        ),
      );
    }
    if (order.status == 'rejected') {
      steps.add(
        (
          label: s('timelineRejected'),
          time: order.updatedAt,
          bad: true,
        ),
      );
    }
    if (order.status == 'cancelled') {
      steps.add(
        (
          label: s('timelineCancelled'),
          time: order.updatedAt,
          bad: true,
        ),
      );
    }
    return Column(
      children: steps.map((step) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: step.bad ? AppColors.red : AppColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step.label, style: const TextStyle(fontSize: 14)),
              ),
              Text(
                fmtDateTime(step.time),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
