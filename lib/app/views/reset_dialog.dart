/*
 * Copyright (C) 2024 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../app/logging.dart';
import '../../core/models.dart';
import '../../desktop/models.dart';
import '../../fido/models.dart';
import '../../fido/state.dart';
import '../../management/models.dart';
import '../../management/state.dart';
import '../../oath/state.dart';
import '../../piv/state.dart';
import '../../widgets/responsive_dialog.dart';
import '../message.dart';
import '../models.dart';
import '../state.dart';

final _log = Logger('fido.views.reset_dialog');

const resetCapabilities = [
  Capability.oath,
  Capability.fido2,
  Capability.piv,
];

class ResetDialog extends ConsumerStatefulWidget {
  final YubiKeyData data;
  const ResetDialog(this.data, {super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<ResetDialog> {
  // TODO: Capabilities based on enabled/supported. Feature checks.
  Capability? _application;
  StreamSubscription<InteractionEvent>? _subscription;
  InteractionEvent? _interaction;
  int _currentStep = -1;
  final _totalSteps = 3;

  String _getMessage() {
    final l10n = AppLocalizations.of(context)!;
    final nfc = widget.data.node.transport == Transport.nfc;
    if (_currentStep == 3) {
      return l10n.l_fido_app_reset;
    }
    return switch (_interaction) {
      InteractionEvent.remove =>
        nfc ? l10n.l_remove_yk_from_reader : l10n.l_unplug_yk,
      InteractionEvent.insert =>
        nfc ? l10n.l_replace_yk_on_reader : l10n.l_reinsert_yk,
      InteractionEvent.touch => l10n.l_touch_button_now,
      null => ''
    };
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        widget.data.info.supportedCapabilities[widget.data.node.transport] ?? 0;
    final enabled = widget
            .data.info.config.enabledCapabilities[widget.data.node.transport] ??
        0;

    final isBio = [FormFactor.usbABio, FormFactor.usbCBio]
        .contains(widget.data.info.formFactor);
    final globalReset = isBio && (supported & Capability.piv.value) != 0;
    final l10n = AppLocalizations.of(context)!;
    double progress = _currentStep == -1 ? 0.0 : _currentStep / (_totalSteps);
    return ResponsiveDialog(
      title: Text(l10n.s_factory_reset),
      onCancel: switch (_application) {
        Capability.fido2 => _currentStep < 3
            ? () {
                _subscription?.cancel();
              }
            : null,
        _ => null,
      },
      actions: [
        if (_currentStep < 3)
          TextButton(
            onPressed: switch (_application) {
              Capability.fido2 => _subscription == null
                  ? () async {
                      _subscription = ref
                          .read(
                              fidoStateProvider(widget.data.node.path).notifier)
                          .reset()
                          .listen((event) {
                        setState(() {
                          _currentStep++;
                          _interaction = event;
                        });
                      }, onDone: () {
                        setState(() {
                          _currentStep++;
                        });
                        _subscription = null;
                      }, onError: (e) {
                        _log.error('Error performing FIDO reset', e);
                        Navigator.of(context).pop();
                        final String errorMessage;
                        // TODO: Make this cleaner than importing desktop specific RpcError.
                        if (e is RpcError) {
                          if (e.status == 'connection-error') {
                            errorMessage = l10n.l_failed_connecting_to_fido;
                          } else if (e.status == 'key-mismatch') {
                            errorMessage = l10n.l_wrong_inserted_yk_error;
                          } else if (e.status == 'user-action-timeout') {
                            errorMessage = l10n.l_user_action_timeout_error;
                          } else {
                            errorMessage = e.message;
                          }
                        } else {
                          errorMessage = e.toString();
                        }
                        showMessage(
                          context,
                          l10n.l_reset_failed(errorMessage),
                          duration: const Duration(seconds: 4),
                        );
                      });
                    }
                  : null,
              Capability.oath => () async {
                  await ref
                      .read(oathStateProvider(widget.data.node.path).notifier)
                      .reset();
                  await ref.read(withContextProvider)((context) async {
                    Navigator.of(context).pop();
                    showMessage(context, l10n.l_oath_application_reset);
                  });
                },
              Capability.piv => () async {
                  await ref
                      .read(pivStateProvider(widget.data.node.path).notifier)
                      .reset();
                  await ref.read(withContextProvider)((context) async {
                    Navigator.of(context).pop();
                    showMessage(context, l10n.l_piv_app_reset);
                  });
                },
              null => globalReset
                  ? () async {
                      await ref
                          .read(managementStateProvider(widget.data.node.path)
                              .notifier)
                          .deviceReset();
                      await ref.read(withContextProvider)((context) async {
                        Navigator.of(context).pop();
                        showMessage(context, l10n.s_factory_reset);
                      });
                    }
                  : null,
              _ => throw UnsupportedError('Application cannot be reset'),
            },
            child: Text(l10n.s_reset),
          )
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!globalReset)
              SegmentedButton<Capability>(
                emptySelectionAllowed: true,
                segments: resetCapabilities
                    .where((c) => supported & c.value != 0)
                    .map((c) => ButtonSegment(
                          value: c,
                          icon: const Icon(null),
                          label: Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: Text(c.getDisplayName(l10n)),
                          ),
                          enabled: enabled & c.value != 0,
                        ))
                    .toList(),
                selected: _application != null ? {_application!} : {},
                onSelectionChanged: (selected) {
                  setState(() {
                    _application = selected.first;
                  });
                },
              ),
            Text(
              switch (_application) {
                Capability.oath => l10n.p_warning_factory_reset,
                Capability.piv => l10n.p_warning_piv_reset,
                Capability.fido2 => l10n.p_warning_deletes_accounts,
                _ => globalReset
                    ? l10n.p_warning_global_reset
                    : l10n.p_factory_reset_an_app,
              },
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              switch (_application) {
                Capability.oath => l10n.p_warning_disable_credentials,
                Capability.piv => l10n.p_warning_piv_reset_desc,
                Capability.fido2 => l10n.p_warning_disable_accounts,
                _ => globalReset
                    ? l10n.p_warning_global_reset_desc
                    : l10n.p_factory_reset_desc,
              },
            ),
            if (_application == Capability.fido2 && _currentStep >= 0) ...[
              Text('${l10n.s_status}: ${_getMessage()}'),
              LinearProgressIndicator(value: progress)
            ],
          ]
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: e,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
