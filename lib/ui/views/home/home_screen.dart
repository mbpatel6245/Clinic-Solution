import 'dart:io';

import 'package:clinic_solution/core/utils/size_utils.dart';
import 'package:clinic_solution/ui/views/home/appointment/tab_appointments.dart';
import 'package:clinic_solution/ui/views/home/new_prescription/tab_new_prescription.dart';
import 'package:clinic_solution/ui/views/home/prescription_list/tab_prescription_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/locale_key.dart';
import '../../../core/utils/locale_provider.dart';
import '../../../services/local/secure_data_viewmodel.dart';
import '../../themes/text_styles.dart';
import '../../widgets/common_text.dart';
import 'home_viewmodel.dart';
import 'stock_inward/tab_stock_inward.dart';

class HomeScreen extends StatelessWidget {
  //final User user;

  HomeScreen({Key? key}) : super(key: key);
  var localeProvider = LocaleProvider();

  @override
  Widget build(BuildContext context) {
    localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SecureDataViewModel()),
        ChangeNotifierProxyProvider<SecureDataViewModel, HomeViewModel>(
            create: (context) {
          var viewModel = HomeViewModel(context.read<SecureDataViewModel>());
          // viewModel.loadUser(user); // Load user once
          return viewModel;
        }, update: (context, secureDataViewModel, homeViewModel) {
          //    homeViewModel!..loadUser(user),
          return HomeViewModel(context.read<SecureDataViewModel>());
        }),
      ],
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Consumer2<HomeViewModel, SecureDataViewModel>(
              builder: (context, homeViewModel, secureDataViewModel, child) {
                return FutureBuilder<List<String?>>(
                    future: Future.wait([
                      secureDataViewModel.getEmail(),
                      secureDataViewModel.getDisplayName()
                    ]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Show loading indicator
                      } else if (snapshot.hasError) {
                        return CommonText(text: 'Error: ${snapshot.error}');
                      } else {
                        String email = snapshot.data?[0] ?? 'No email';
                        String displayName = snapshot.data?[1] ?? 'User';

                        return CommonText(
                          text: 'Welcome, $displayName ($email)',
                          style: AppTextStyles.getRegularTextStyle(
                              localeProvider.locale),
                        );
                      }
                    });
              },
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  context.go('/${Strings.navLogin}');
                },
                icon: const Icon(Icons.logout),
              ),
            ],
            bottom: TabBar(
              labelPadding: const EdgeInsets.symmetric(horizontal: 0),
              indicator: const BoxDecoration(
                color: Colors.green,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black,
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              labelStyle: const TextStyle(fontSize: 12),
              automaticIndicatorColorAdjustment: true,
              tabs: [
                Tab(
                  child: commonTabView(context, Icons.library_add_rounded,
                      AppLocalizations.of(context)?.newPrescription ?? ''),
                ),
                Tab(
                  child: commonTabView(context, Icons.list,
                      AppLocalizations.of(context)?.prescriptionList ?? ''),
                ),
                Tab(
                  child: commonTabView(context, Icons.book_online,
                      AppLocalizations.of(context)?.appointments ?? ''),
                ),
                Tab(
                  child: commonTabView(context, Icons.add_home_work_rounded,
                      AppLocalizations.of(context)?.stockInward ?? ''),
                ),
              ],
            ),
          ),
          body: Center(
            child: Consumer2<HomeViewModel, SecureDataViewModel>(
              builder: (context, homeViewModel, secureDataViewModel, child) {
                return FutureBuilder<List<String?>>(
                    future: Future.wait([
                      secureDataViewModel.getEmail(),
                      secureDataViewModel.getDisplayName()
                    ]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Show loading indicator
                      } else if (snapshot.hasError) {
                        return CommonText(text: 'Error: ${snapshot.error}');
                      } else {
                        // String email = snapshot.data?[0] ?? 'No email';
                        // String displayName = snapshot.data?[1] ?? 'User';

                        return Column(
                          children: [
                            // Text(
                            //   'Welcome, $displayName '
                            //   '($email)',
                            // ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  TabNewPrescription(),
                                  TabPrescriptionList(),
                                  TabAppointments(),
                                  TabStockInward(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget commonTabView(
      BuildContext context, IconData iconData, String tabTitle) {
    if (kIsWeb) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData),
          const SizedBox(width: 5),
          CommonText(
            text: tabTitle,
            style: AppTextStyles.getSemiBoldTextStyle(localeProvider.locale),
            height: getSize(40),
          ),
        ],
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData),
            const SizedBox(width: 5),
            CommonText(
              text: tabTitle,
              style: AppTextStyles.getSemiBoldTextStyle(localeProvider.locale,
                  fontSize: 10),
              textAlign: TextAlign.center,
              height: getSize(15),
            ),
          ],
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData),
          const SizedBox(width: 5),
          CommonText(
            text: tabTitle,
            style: AppTextStyles.getSemiBoldTextStyle(localeProvider.locale),
          ),
        ],
      );
    }
  }
}
// Platform-specific title example
//   String _getPlatformSpecificTitle() {
//     if (kIsWeb) {
//       return "Web TabBar";
//     } else if (Platform.isAndroid) {
//       return "Android TabBar";
//     } else if (Platform.isIOS) {
//       return "iOS TabBar";
//     } else if (Platform.isLinux) {
//       return "Linux TabBar";
//     } else if (Platform.isMacOS) {
//       return "MacOS TabBar";
//     } else if (Platform.isWindows) {
//       return "Windows TabBar";
//     } else {
//       return "TabBar";
//     }
//   }
// }
