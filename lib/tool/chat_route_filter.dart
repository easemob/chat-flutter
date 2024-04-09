import 'package:chat_uikit_demo/demo_localizations.dart';
import 'package:chat_uikit_demo/pages/call/call_pages/multi_call_page.dart';
import 'package:chat_uikit_demo/pages/call/call_pages/single_call_page.dart';
import 'package:chat_uikit_demo/pages/call/group_member_select_view.dart';
import 'package:chat_uikit_demo/pages/help/download_page.dart';
import 'package:chat_uikit_demo/tool/app_server_helper.dart';
import 'package:chat_uikit_demo/tool/user_data_store.dart';
import 'package:em_chat_callkit/chat_callkit.dart';
import 'package:em_chat_uikit/chat_uikit.dart';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatRouteFilter {
  static RouteSettings chatRouteSettings(RouteSettings settings) {
    // 拦截 ChatUIKitRouteNames.messagesView, 之后对要跳转的页面的 `RouteSettings` 进行自定义，之后返回。
    if (settings.name == ChatUIKitRouteNames.messagesView) {
      return messagesView(settings);
    } else if (settings.name == ChatUIKitRouteNames.createGroupView) {
      return createGroupView(settings);
    } else if (settings.name == ChatUIKitRouteNames.contactDetailsView) {
      return contactDetail(settings);
    } else if (settings.name == ChatUIKitRouteNames.groupDetailsView) {
      return groupDetail(settings);
    }
    return settings;
  }

  static RouteSettings groupDetail(RouteSettings settings) {
    ChatUIKitViewObserver? viewObserver = ChatUIKitViewObserver();
    GroupDetailsViewArguments arguments = settings.arguments as GroupDetailsViewArguments;

    arguments = arguments.copyWith(viewObserver: viewObserver);
    // 更新群详情
    Future(() async {
      Group group = await ChatUIKit.instance.fetchGroupInfo(groupId: arguments.profile.id);
      ChatUIKitProfile profile = arguments.profile.copyWith(name: group.name, avatarUrl: group.extension);
      ChatUIKitProvider.instance.addProfiles([profile]);
      UserDataStore().saveUserData(profile);
    }).then((value) {
      // 刷新ui
      viewObserver.refresh();
    }).catchError((e) {
      debugPrint('fetch group info error');
    });
    return RouteSettings(name: settings.name, arguments: arguments);
  }

  // 自定义 contact detail view
  static RouteSettings contactDetail(RouteSettings settings) {
    ContactDetailsViewArguments arguments = settings.arguments as ContactDetailsViewArguments;
    arguments = arguments.copyWith(
      actionsBuilder: (context) {
        List<ChatUIKitModelAction> moreActions = [];

        moreActions.add(
          ChatUIKitModelAction(
            title: ChatUIKitLocal.contactDetailViewSend.localString(context),
            icon: 'assets/images/chat.png',
            iconSize: const Size(32, 32),
            packageName: ChatUIKitImageLoader.packageName,
            onTap: (ctx) {
              Navigator.of(context).pushNamed(
                ChatUIKitRouteNames.messagesView,
                arguments: MessagesViewArguments(
                  profile: arguments.profile,
                  attributes: arguments.attributes,
                ),
              );
            },
          ),
        );

        moreActions.add(
          ChatUIKitModelAction(
            title: DemoLocalizations.voiceCall.localString(context),
            icon: 'assets/images/voice_call.png',
            iconSize: const Size(32, 32),
            onTap: (context) {
              [Permission.microphone, Permission.camera].request().then((value) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) {
                    return SingleCallPage.call(arguments.profile.id, type: ChatCallKitCallType.audio_1v1);
                  }),
                ).then((value) {
                  if (value != null) {
                    debugPrint('call end: $value');
                  }
                });
              });
            },
          ),
        );

        moreActions.add(
          ChatUIKitModelAction(
            title: DemoLocalizations.videoCall.localString(context),
            icon: 'assets/images/video_call.png',
            iconSize: const Size(32, 32),
            onTap: (context) {
              [Permission.microphone, Permission.camera].request().then((value) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) {
                    return SingleCallPage.call(arguments.profile.id, type: ChatCallKitCallType.video_1v1);
                  }),
                ).then((value) {
                  if (value != null) {
                    debugPrint('call end: $value');
                  }
                });
              });
            },
          ),
        );

        moreActions.add(ChatUIKitModelAction(
          title: ChatUIKitLocal.contactDetailViewSearch.localString(context),
          icon: 'assets/images/search_history.png',
          iconSize: const Size(32, 32),
          packageName: ChatUIKitImageLoader.packageName,
          onTap: (context) {
            ChatUIKitRoute.pushOrPushNamed(
              context,
              ChatUIKitRouteNames.searchHistoryView,
              SearchHistoryViewArguments(
                profile: arguments.profile,
                attributes: arguments.attributes,
              ),
            ).then((value) {
              if (value != null && value is Message) {
                ChatUIKitRoute.pushOrPushNamed(
                  context,
                  ChatUIKitRouteNames.messagesView,
                  MessagesViewArguments(
                    profile: arguments.profile,
                    attributes: arguments.attributes,
                    controller: MessageListViewController(
                      profile: arguments.profile,
                      searchedMsg: value,
                    ),
                  ),
                );
              }
            });
          },
        ));

        return moreActions;
      },
      // 添加 remark 实现
      contentWidgetBuilder: (context) {
        return InkWell(
          onTap: () async {
            String? remark = await showChatUIKitDialog(
              context: context,
              title: DemoLocalizations.contactRemark.localString(context),
              hintsText: [DemoLocalizations.contactRemarkDesc.localString(context)],
              items: [
                ChatUIKitDialogItem.inputsConfirm(
                  label: DemoLocalizations.contactRemarkConfirm.localString(context),
                  onInputsTap: (inputs) async {
                    Navigator.of(context).pop(inputs.first);
                  },
                ),
                ChatUIKitDialogItem.cancel(label: DemoLocalizations.contactRemarkCancel.localString(context)),
              ],
            );

            if (remark?.isNotEmpty == true) {
              ChatUIKit.instance.updateContactRemark(arguments.profile.id, remark!).then((value) {
                ChatUIKitProfile profile = arguments.profile.copyWith(remark: remark);
                // 更新数据，并设置到provider中
                UserDataStore().saveUserData(profile);
                ChatUIKitProvider.instance.addProfiles([profile]);
              }).catchError((e) {
                EasyLoading.showError(DemoLocalizations.contactRemarkFailed.localString(context));
              });
            }
          },
          child: ChatUIKitDetailsListViewItem(
            title: DemoLocalizations.contactRemark.localString(context),
            trailing: Text(ChatUIKitProvider.instance.getProfile(arguments.profile).remark ?? ''),
          ),
        );
      },
    );

    // 异步更新用户信息
    Future(() async {
      String userId = arguments.profile.id;
      try {
        Map<String, UserInfo> map = await ChatUIKit.instance.fetchUserInfoByIds([userId]);
        UserInfo? userInfo = map[userId];
        Contact? contact = await ChatUIKit.instance.getContact(userId);
        if (contact != null) {
          ChatUIKitProfile profile = ChatUIKitProfile.contact(
            id: contact.userId,
            nickname: userInfo?.nickName,
            avatarUrl: userInfo?.avatarUrl,
            remark: contact.remark,
          );
          // 更新数据，并设置到provider中
          UserDataStore().saveUserData(profile);
          ChatUIKitProvider.instance.addProfiles([profile]);
        }
      } catch (e) {
        debugPrint('fetch user info error');
      }
    }).catchError((e) {});

    return RouteSettings(name: settings.name, arguments: arguments);
  }

  // 为 MessagesView 添加文件点击下载
  static RouteSettings messagesView(RouteSettings settings) {
    MessagesViewArguments arguments = settings.arguments as MessagesViewArguments;
    MessageListViewController controller = MessageListViewController(profile: arguments.profile);

    arguments = arguments.copyWith(
      controller: controller,
      showMessageItemNickname: (model) {
        // 只有群组消息并且不是自己发的消息显示昵称
        return (arguments.profile.type == ChatUIKitProfileType.group) &&
            model.message.from != ChatUIKit.instance.currentUserId;
      },
      onItemTap: (ctx, messageModel) {
        if (messageModel.message.bodyType == MessageType.FILE) {
          Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (context) => DownloadFileWidget(
                message: messageModel.message,
                key: ValueKey(messageModel.message.localTime),
              ),
            ),
          );
          return true;
        }
        return false;
      },
      appBarTrailingActionsBuilder: (context, defaultList) {
        List<ChatUIKitAppBarTrailingAction>? actions = [];
        if (defaultList != null) {
          actions.addAll(defaultList);
        }
        if (!controller.isMultiSelectMode) {
          actions.add(
            ChatUIKitAppBarTrailingAction(
              onTap: (context) {
                ChatUIKitColor color = ChatUIKitTheme.of(context).color;
                // 如果是单聊，弹出选择语音通话和视频通话
                if (arguments.profile.type == ChatUIKitProfileType.contact) {
                  showChatUIKitBottomSheet(
                    context: context,
                    items: [
                      ChatUIKitBottomSheetItem.normal(
                        icon: Image.asset(
                          'assets/images/voice_call.png',
                          color: color.isDark ? color.primaryColor6 : color.primaryColor5,
                        ),
                        label: DemoLocalizations.voiceCall.localString(context),
                        onTap: () async {
                          Navigator.of(context).pop();
                          [Permission.microphone, Permission.camera].request().then((value) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) {
                                return SingleCallPage.call(arguments.profile.id, type: ChatCallKitCallType.audio_1v1);
                              }),
                            ).then((value) {
                              if (value != null) {
                                debugPrint('call end: $value');
                              }
                            });
                          });
                        },
                      ),
                      ChatUIKitBottomSheetItem.normal(
                        icon: Image.asset(
                          'assets/images/video_call.png',
                          color: color.isDark ? color.primaryColor6 : color.primaryColor5,
                        ),
                        label: DemoLocalizations.videoCall.localString(context),
                        onTap: () async {
                          Navigator.of(context).pop();
                          [Permission.microphone, Permission.camera].request().then((value) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) {
                                return SingleCallPage.call(arguments.profile.id, type: ChatCallKitCallType.video_1v1);
                              }),
                            ).then((value) {
                              if (value != null) {
                                debugPrint('call end: $value');
                              }
                            });
                          });
                        },
                      ),
                    ],
                  );
                } else {
                  // 如果是群聊，直接选择联系人
                  Navigator.of(context)
                      .push(
                    MaterialPageRoute(
                      builder: (context) => GroupMemberSelectView(
                        groupId: arguments.profile.id,
                      ),
                    ),
                  )
                      .then((value) {
                    if (value is List<ChatUIKitProfile> && value.isNotEmpty) {
                      List<String> userIds = value.map((e) => e.id).toList();
                      [Permission.microphone, Permission.camera].request().then((value) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) {
                            return MultiCallPage.call(
                              userIds,
                              groupId: arguments.profile.id,
                            );
                          }),
                        ).then((value) {
                          if (value != null) {
                            debugPrint('call end: $value');
                          }
                        });
                      });
                    }
                  });
                }
              },
              child: Image.asset('assets/images/call.png', fit: BoxFit.fill, width: 32, height: 32),
            ),
          );
        }

        return actions;
      },
    );

    return RouteSettings(name: settings.name, arguments: arguments);
  }

  // 添加创建群组拦截，并添加设置群名称功能
  static RouteSettings createGroupView(RouteSettings settings) {
    CreateGroupViewArguments arguments = settings.arguments as CreateGroupViewArguments;
    arguments = arguments.copyWith(
      createGroupHandler: (context, selectedProfiles) async {
        String? groupName = await showChatUIKitDialog(
          context: context,
          title: DemoLocalizations.createGroupName.localString(context),
          hintsText: [DemoLocalizations.createGroupDesc.localString(context)],
          items: [
            ChatUIKitDialogItem.inputsConfirm(
              label: DemoLocalizations.createGroupConfirm.localString(context),
              onInputsTap: (inputs) async {
                Navigator.of(context).pop(inputs.first);
              },
            ),
            ChatUIKitDialogItem.cancel(
              label: DemoLocalizations.createGroupCancel.localString(context),
            ),
          ],
        );

        if (groupName != null) {
          return CreateGroupInfo(
            groupName: groupName,
            onGroupCreateCallback: (group, error) {
              if (error != null) {
                showChatUIKitDialog(
                  context: context,
                  title: DemoLocalizations.createGroupFailed.localString(context),
                  content: error.description,
                  items: [
                    ChatUIKitDialogItem.confirm(label: DemoLocalizations.createGroupConfirm.localString(context)),
                  ],
                );
              } else {
                Navigator.of(context).pop();
                if (group != null) {
                  AppServerHelper.autoDestroyGroup(group.groupId);
                  ChatUIKitRoute.pushOrPushNamed(
                    context,
                    ChatUIKitRouteNames.messagesView,
                    MessagesViewArguments(
                      profile: ChatUIKitProfile.group(id: group.groupId, groupName: group.name),
                    ),
                  );
                }
              }
            },
          );
        } else {
          return null;
        }
      },
    );

    return RouteSettings(name: settings.name, arguments: arguments);
  }
}
