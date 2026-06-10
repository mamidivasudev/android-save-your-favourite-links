400:                               },
401:                             )
402:                           : Column(
403:                               crossAxisAlignment: CrossAxisAlignment.start,
404:                               children: [
405:                                 Text(
406:                                   'My Links 📌',
407:                                   style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
408:                                 ),
409:                                 Text(
410:                                   '  Save it now, find it later',
411:                                   style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
412:                                 ),
413:                               ],
414:                             ),
415:                   centerTitle: false,
416:                   titleSpacing: 0,
417:                   elevation: 0,
418:                   backgroundColor: Colors.transparent,
419:                   iconTheme: const IconThemeData(color: Colors.white),
420:                   actionsIconTheme: const IconThemeData(color: Colors.white),
421:                   flexibleSpace: Container(
422:                     decoration: BoxDecoration(
423:                       gradient: LinearGradient(
424:                         colors: _isSelectionMode 
425:                           ? [Colors.red.shade800, Colors.red.shade600]
426:                           : [Colors.blue.shade800, Colors.purple.shade700],
427:                         begin: Alignment.topLeft,
428:                         end: Alignment.bottomRight,
429:                       ),
430:                     ),
431:                   ),
432:                   leading: _isSelectionMode
433:                       ? IconButton(
434:                           icon: const Icon(Icons.close, color: Colors.white),
435:                           onPressed: () {
436:                             setState(() {
437:                               _isSelectionMode = false;
438:                               _selectedLinkIds.clear();
439:                             });
440:                           },
441:                         )
442:                       : Showcase(
443:                           key: _menuKey,
444:                           description: 'Open the menu to create folders, change themes, and enable Cloud Backup.',
445:                           child: Builder(
446:                             builder: (ctx) => IconButton(
447:                               icon: const Icon(Icons.menu, color: Colors.white),
448:                               onPressed: () => Scaffold.of(ctx).openDrawer(),
449:                             ),
450:                           ),
451:                         ),
452:                   actions: [
453:                     if (_isSelectionMode) ...[
454:                       IconButton(
455:                         icon: const Icon(Icons.select_all, color: Colors.white),
456:                         onPressed: () => _selectAll(provider.links),
457:                       ),
458:                       IconButton(
459:                         icon: const Icon(Icons.delete, color: Colors.white),
460:                         onPressed: _deleteSelected,
461:                       ),
462:                     ] else ...[
463:                       if (!provider.isProUser)
464:                         InkWell(
465:                           onTap: () {
466:                             Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
467:                           },
468:                           child: Padding(
469:                             padding: const EdgeInsets.symmetric(horizontal: 6),
470:                             child: Column(
471:                               mainAxisAlignment: MainAxisAlignment.center,
472:                               children: [
473:                                 const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
474:                                 Text('Pro', style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
475:                               ],
476:                             ),
477:                           ),
478:                         ),
479:                       Showcase(
480:                         key: _searchKey,
481:                         description: 'Search for any saved link instantly right here.',
482:                         child: InkWell(
483:                           onTap: () {
484:                             setState(() {
485:                               if (_isSearching) {
486:                                 _isSearching = false;
487:                                 _searchController.clear();
488:                                 _searchQuery = '';
489:                               } else {
490:                                 _isSearching = true;
491:                               }
492:                             });
493:                           },
494:                           child: Padding(
495:                             padding: const EdgeInsets.symmetric(horizontal: 6),
496:                             child: Column(
497:                               mainAxisAlignment: MainAxisAlignment.center,
498:                               children: [
499:                                 Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
500:                                 Text(_isSearching ? 'Close' : 'Search', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
501:                               ],
502:                             ),
503:                           ),
504:                         ),
505:                       ),
506:                       PopupMenuButton<SortOption>(
507:                         padding: EdgeInsets.zero,
508:                         tooltip: 'Sort Options',
509:                         offset: const Offset(0, 45),
510:                         onSelected: (SortOption result) {
511:                           setState(() {
512:                             _currentSort = result;
513:                           });
514:                         },
515:                         itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
516:                           const PopupMenuItem<SortOption>(
517:                             value: SortOption.newest,
518:                             child: Text('Newest First'),
519:                           ),
520:                           const PopupMenuItem<SortOption>(
521:                             value: SortOption.oldest,
522:                             child: Text('Oldest First'),
523:                           ),
524:                           const PopupMenuItem<SortOption>(
525:                             value: SortOption.aToZ,
526:                             child: Text('Alphabetical (A-Z)'),
527:                           ),
528:                           const PopupMenuItem<SortOption>(
529:                             value: SortOption.zToA,
530:                             child: Text('Alphabetical (Z-A)'),
531:                           ),
532:                         ],
533:                         child: Padding(
534:                           padding: const EdgeInsets.symmetric(horizontal: 6),
535:                           child: Column(
536:                             mainAxisAlignment: MainAxisAlignment.center,
537:                             children: [
538:                               const Icon(Icons.sort, color: Colors.white, size: 20),
539:                               Text('Sort', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
540:                             ],
541:                           ),
542:                         ),
543:                       ),
544:                       InkWell(
545:                         onTap: _isSyncing ? null : _syncToGoogleDrive,
546:                         child: Padding(
547:                           padding: const EdgeInsets.symmetric(horizontal: 6),
548:                           child: Column(
549:                             mainAxisAlignment: MainAxisAlignment.center,
550:                             children: [
551:                               _isSyncing
552:                                   ? const SizedBox(
553:                                       width: 20,
554:                                       height: 20,
555:                                       child: CircularProgressIndicator(
556:                                         color: Colors.white,
557:                                         strokeWidth: 2.0,
558:                                       ),
559:                                     )
560:                                   : const Icon(Icons.cloud_sync, color: Colors.white, size: 20),
561:                               Text('Sync', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
562:                             ],
563:                           ),
564:                         ),
565:                       ),
566:                     ]
567:                   ],
568:                   bottom: TabBar(
569:                     isScrollable: true,
570:                     tabAlignment: TabAlignment.start,
571:                     padding: const EdgeInsets.only(left: 8),
572:                     tabs: categories.map((category) {
573:                       final count = category.id == -1 
574:                           ? provider.links.length 
575:                           : provider.links.where((l) => l.categoryId == category.id).length;
576:                       return Tab(text: '${category.name} ($count)');
577:                     }).toList(),
578:                     labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
579:                     unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13),
580:                     indicatorColor: Colors.white,
581:                     labelColor: Colors.white,
582:                     unselectedLabelColor: Colors.white70,
583:                     indicatorWeight: 3,
584:                   ),
585:                 ),
586:                 floatingActionButton: Showcase(
587:                   key: _addKey,
588:                   description: 'Tap here to save your very first link!',
589:                   child: FloatingActionButton(
590:                     onPressed: () {
591:                       // Impose 50 link limit for free users
592:                       if (!provider.isProUser && provider.links.length >= 50) {
593:                         Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
594:                           children: [
595:                             const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
596:                             Text('Pro', style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
597:                           ],
598:                         ),
599:                       ),
600:                     ),
601:                   Showcase(
602:                     key: _searchKey,
603:                     description: 'Search for any saved link instantly right here.',
604:                     child: InkWell(
605:                       onTap: () {
606:                         setState(() {
607:                           if (_isSearching) {
608:                             _isSearching = false;
609:                             _searchController.clear();
610:                             _searchQuery = '';
611:                           } else {
612:                             _isSearching = true;
613:                           }
614:                         });
615:                       },
616:                       child: Padding(
617:                         padding: const EdgeInsets.symmetric(horizontal: 6),
618:                         child: Column(
619:                           mainAxisAlignment: MainAxisAlignment.center,
620:                           children: [
621:                             Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
622:                             Text(_isSearching ? 'Close' : 'Search', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
623:                           ],
624:                         ),
625:                       ),
626:                     ),
627:                   ),
628:                   PopupMenuButton<SortOption>(
629:                     padding: EdgeInsets.zero,
630:                     tooltip: 'Sort Options',
631:                     offset: const Offset(0, 45),
632:                     onSelected: (SortOption result) {
633:                       setState(() {
634:                         _currentSort = result;
635:                       });
636:                     },
637:                     itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
638:                       const PopupMenuItem<SortOption>(
639:                         value: SortOption.newest,
640:                         child: Text('Newest First'),
641:                       ),
642:                       const PopupMenuItem<SortOption>(
643:                         value: SortOption.oldest,
644:                         child: Text('Oldest First'),
645:                       ),
646:                       const PopupMenuItem<SortOption>(
647:                         value: SortOption.aToZ,
648:                         child: Text('Alphabetical (A-Z)'),
649:                       ),
650:                       const PopupMenuItem<SortOption>(
651:                         value: SortOption.zToA,
652:                         child: Text('Alphabetical (Z-A)'),
653:                       ),
654:                     ],
655:                     child: Padding(
656:                       padding: const EdgeInsets.symmetric(horizontal: 6),
657:                       child: Column(
658:                         mainAxisAlignment: MainAxisAlignment.center,
659:                         children: [
660:                           const Icon(Icons.sort, color: Colors.white, size: 20),
661:                           Text('Sort', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
662:                         ],
663:                       ),
664:                     ),
665:                   ),
666:                   InkWell(
667:                     onTap: _isSyncing ? null : _syncToGoogleDrive,
668:                     child: Padding(
669:                       padding: const EdgeInsets.symmetric(horizontal: 6),
670:                       child: Column(
671:                         mainAxisAlignment: MainAxisAlignment.center,
672:                         children: [
673:                           _isSyncing
674:                               ? const SizedBox(
675:                                   width: 20,
676:                                   height: 20,
677:                                   child: CircularProgressIndicator(
678:                                     color: Colors.white,
679:                                     strokeWidth: 2.0,
680:                                   ),
681:                                 )
682:                               : const Icon(Icons.cloud_sync, color: Colors.white, size: 20),
683:                           Text('Sync', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
684:                         ],
685:                       ),
686:                     ),
687:                   ),
688:                 ]
689:               ],
690:               bottom: TabBar(
691:                 isScrollable: true,
692:                 tabAlignment: TabAlignment.start,
693:                 padding: const EdgeInsets.only(left: 8),
694:                 tabs: categories.map((category) {
695:                   final count = category.id == -1 
696:                       ? provider.links.length 
697:                       : provider.links.where((l) => l.categoryId == category.id).length;
698:                   return Tab(text: '${category.name} ($count)');
699:                 }).toList(),
700:                 labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
701:                 unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 13),
702:                 indicatorColor: Colors.white,
703:                 labelColor: Colors.white,
704:                 unselectedLabelColor: Colors.white70,
705:                 indicatorWeight: 3,
706:               ),
707:             ),
708:             drawer: AppDrawer(
709:               onCategoriesTap: () => _showManageCategoriesDialog(context),
710:               onStorageFolderTap: _showFolderPicker,
711:             ),
712:             body: provider.links.isEmpty
713:                 ? _buildEmptyState()
714:                 : TabBarView(
715:                     children: categories.map((category) {
716:                       var filteredLinks = provider.links.where((link) {
717:                         // Category filter
718:                         bool matchesCategory = category.id == -1 || link.categoryId == category.id;
719:                         if (!matchesCategory) return false;
720:                         
721:                         // Search filter
722:                         if (_searchQuery.isNotEmpty) {
723:                           return link.title.toLowerCase().contains(_searchQuery) ||
724:                                  link.url.toLowerCase().contains(_searchQuery);
725:                         }
726:                         return true;
727:                       }).toList();
728: 
729:                       // Apply sorting
730:                       filteredLinks.sort((a, b) {
731:                         if (a.isPinned && !b.isPinned) return -1;
732:                         if (!a.isPinned && b.isPinned) return 1;
733: 
734:                         switch (_currentSort) {
735:                           case SortOption.newest:
736:                             return b.createdAt.compareTo(a.createdAt);
737:                           case SortOption.oldest:
738:                             return a.createdAt.compareTo(b.createdAt);
739:                           case SortOption.aToZ:
740:                             return a.title.toLowerCase().compareTo(b.title.toLowerCase());
741:                           case SortOption.zToA:
742:                             return b.title.toLowerCase().compareTo(a.title.toLowerCase());
743:                         }
744:                       });
745: 
746:                       if (filteredLinks.isEmpty) {
747:                         return Center(
748:                           child: Text(
749:                             'No ${category.name} links',
750:                             style: GoogleFonts.poppins(color: Colors.grey.shade500),
751:                           ),
752:                         );
753:                       }
754: 
755:                       return ListView.builder(
756:                         padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
757:                         itemCount: filteredLinks.length,
758:                         itemBuilder: (context, index) {
759:                           final link = filteredLinks[index];
760:                           final isSelected = _selectedLinkIds.contains(link.id);
761:                           return LinkCard(
762:                             link: link,
763:                             isSelected: isSelected,
764:                             isSelectionMode: _isSelectionMode,
765:                             onTap: () async {
766:                               if (_isSelectionMode) {
767:                                 _toggleSelection(link.id!);
768:                               } else {
769:                                 if (link.isLocked) {
770:                                   final provider = Provider.of<LinkProvider>(context, listen: false);
771:                                   provider.setAuthenticating(true);
772:                                   final authenticated = await AuthService.authenticateForLink();
773:                                   provider.setAuthenticating(false);
774:                                   if (!authenticated) return;
775:                                 }
776: 
777:                                 final Uri url = Uri.parse(link.url);
778:                                 if (!await launchUrl(
779:                                   url,
780:                                   mode: LaunchMode.externalApplication
781:                                 )) {
782:                                   if (context.mounted) {
783:                                     ScaffoldMessenger.of(context).showSnackBar(
784:                                       SnackBar(content: Text('Could not launch ${link.url}')),
785:                                     );
786:                                   }
787:                                 }
788:                               }
789:                             },
790:                             onLongPress: () => _toggleSelection(link.id!),
791:                           );
792:                         },
793:                       );
794:                     }).toList(),
795:                   ),
796:             floatingActionButton: _isSelectionMode ? null : Showcase(
797:               key: _addKey,
798:               description: 'Tap here to save your very first link!',
799:               child: FloatingActionButton(
800:                 onPressed: () => _onFabPressed(context),
801:                 backgroundColor: Colors.blue.shade800,
802:                 foregroundColor: Colors.white,
803:                 child: const Icon(Icons.add),
804:               ),
805:             ),
806:           ),
807:         );
808:       },
809:     );
810: 
811:   }
812: 
813:   void _onFabPressed(BuildContext context) async {
814:     final provider = Provider.of<LinkProvider>(context, listen: false);
815:     bool setupCompleted = await provider.hasCompletedSetup();
816:     bool hasCustomFolder = await provider.hasCustomStoragePath();
817:     bool isDriveSignedIn = await provider.isDriveSignedIn();
818: 
819:     if (!setupCompleted && !hasCustomFolder && !isDriveSignedIn && mounted) {
820:       _showSetupPrompt(context);
821:     } else {
822:       // If any is configured, or they already clicked "Skip", just show add dialog
823:       _showAddDialog(context);
824:     }
825:   }
826: 
827:   void _showSetupPrompt(BuildContext context) {
828:     showDialog(
829:       context: context,
830:       barrierDismissible: false,
831:       builder: (ctx) => AlertDialog(
832:         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
833:         title: Text('Setup Storage', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
834:         content: Text(
835:           'Where would you like to save your links?\n\n'
836:           '• Local Folder: Pick a visible folder on your phone.\n'
837:           '• Google Drive: Sync across devices.\n'
838:           '• Use Default: Save to internal hidden app storage.',
839:           style: GoogleFonts.poppins(fontSize: 14),
840:         ),
841:         actions: [
842:           TextButton(
843:             onPressed: () async {
844:               Navigator.of(ctx).pop();
845:               await Provider.of<LinkProvider>(context, listen: false).setSetupCompleted(true);
846:               if (mounted) _showAddDialog(context);
847:             },
848:             child: Text('Use Default', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
849:           ),
