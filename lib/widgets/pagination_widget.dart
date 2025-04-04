// lib/widgets/pagination_widget.dart
import 'package:flutter/material.dart';
import 'package:retroachievements_organizer/constants/constants.dart';

class PaginatedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;
  final int pageSize;
  final bool showPageNumbers;
  final String? noItemsMessage;

  const PaginatedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.padding = const EdgeInsets.all(8),
    this.pageSize = PaginationConstants.defaultPageSize,
    this.showPageNumbers = true,
    this.noItemsMessage,
  });

  @override
  State<PaginatedGridView> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  int _currentPage = PaginationConstants.defaultInitialPage;
  late int _totalPages;
  late List<T> _currentPageItems;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _calculatePages();
  }

  @override
  void didUpdateWidget(covariant PaginatedGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items || oldWidget.pageSize != widget.pageSize) {
      _calculatePages();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _calculatePages() {
    _totalPages = (widget.items.length / widget.pageSize).ceil();
    if (_totalPages == 0) _totalPages = 1; // At least one page even if empty
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    _updateCurrentPageItems();
  }

  void _updateCurrentPageItems() {
    final startIndex = (_currentPage - 1) * widget.pageSize;
    final endIndex = startIndex + widget.pageSize > widget.items.length 
        ? widget.items.length 
        : startIndex + widget.pageSize;
    
    if (startIndex >= widget.items.length) {
      _currentPageItems = [];
    } else {
      _currentPageItems = widget.items.sublist(startIndex, endIndex);
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _updateCurrentPageItems();
    });
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.noItemsMessage ?? AppStrings.noGamesFound,
          style: const TextStyle(color: AppColors.textLight, fontSize: 18),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: widget.padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
            ),
            itemCount: _currentPageItems.length,
            itemBuilder: (context, index) => widget.itemBuilder(
              context, 
              _currentPageItems[index], 
              ((_currentPage - 1) * widget.pageSize) + index
            ),
          ),
        ),
        if (_totalPages > 1 && widget.showPageNumbers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildPaginationControls(),
          ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.first_page, color: AppColors.primary),
          onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
          splashRadius: 20,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary),
          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          splashRadius: 20,
        ),
        const SizedBox(width: 8),
        _buildPageNumbers(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.primary),
          onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
          splashRadius: 20,
        ),
        IconButton(
          icon: const Icon(Icons.last_page, color: AppColors.primary),
          onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildPageNumbers() {
    if (_totalPages <= 7) {
      // Show all page numbers if total pages are 7 or less
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_totalPages, (index) {
          return _buildPageButton(index + 1);
        }),
      );
    } else {
      // Show limited page numbers with ellipsis for many pages
      List<Widget> pageButtons = [];
      
      // Always show first page
      pageButtons.add(_buildPageButton(1));
      
      // Add ellipsis if current page is not near the start
      if (_currentPage > 3) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: AppColors.textLight)),
        ));
      }
      
      // Pages around current page
      for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
        if (i > 1 && i < _totalPages) {
          pageButtons.add(_buildPageButton(i));
        }
      }
      
      // Add ellipsis if current page is not near the end
      if (_currentPage < _totalPages - 2) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: AppColors.textLight)),
        ));
      }
      
      // Always show last page
      pageButtons.add(_buildPageButton(_totalPages));
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: pageButtons,
      );
    }
  }

  Widget _buildPageButton(int pageNum) {
    final isCurrentPage = pageNum == _currentPage;
    return InkWell(
      onTap: isCurrentPage ? null : () => _goToPage(pageNum),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isCurrentPage ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrentPage ? AppColors.primary : AppColors.textSubtle,
          ),
        ),
        child: Center(
          child: Text(
            '$pageNum',
            style: TextStyle(
              color: isCurrentPage ? AppColors.darkBackground : AppColors.textLight,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final EdgeInsets padding;
  final int pageSize;
  final bool showPageNumbers;
  final String? noItemsMessage;
  final double itemExtent;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(8),
    this.pageSize = PaginationConstants.defaultPageSize,
    this.showPageNumbers = true,
    this.noItemsMessage,
    this.itemExtent = 0,
  });

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState<T>();
}

// In pagination_widget.dart, add these new classes:

class SingleListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final EdgeInsets padding;
  final String? noItemsMessage;
  final double itemExtent;

  const SingleListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(8),
    this.noItemsMessage,
    this.itemExtent = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          noItemsMessage ?? AppStrings.noGamesFound,
          style: const TextStyle(color: AppColors.textLight, fontSize: 18),
        ),
      );
    }

    return itemExtent > 0
        ? ListView.builder(
            padding: padding,
            itemCount: items.length,
            itemExtent: itemExtent,
            itemBuilder: (context, index) => itemBuilder(
              context,
              items[index],
              index,
            ),
          )
        : ListView.builder(
            padding: padding,
            itemCount: items.length,
            itemBuilder: (context, index) => itemBuilder(
              context,
              items[index],
              index,
            ),
          );
  }
}

class SingleGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;
  final String? noItemsMessage;

  const SingleGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 4,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.padding = const EdgeInsets.all(8),
    this.noItemsMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          noItemsMessage ?? AppStrings.noGamesFound,
          style: const TextStyle(color: AppColors.textLight, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(
        context,
        items[index],
        index,
      ),
    );
  }
}


class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  int _currentPage = PaginationConstants.defaultInitialPage;
  late int _totalPages;
  late List<T> _currentPageItems;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _calculatePages();
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items || oldWidget.pageSize != widget.pageSize) {
      _calculatePages();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _calculatePages() {
    _totalPages = (widget.items.length / widget.pageSize).ceil();
    if (_totalPages == 0) _totalPages = 1; // At least one page even if empty
    if (_currentPage > _totalPages) _currentPage = _totalPages;
    _updateCurrentPageItems();
  }

  void _updateCurrentPageItems() {
    final startIndex = (_currentPage - 1) * widget.pageSize;
    final endIndex = startIndex + widget.pageSize > widget.items.length 
        ? widget.items.length 
        : startIndex + widget.pageSize;
    
    if (startIndex >= widget.items.length) {
      _currentPageItems = [];
    } else {
      _currentPageItems = widget.items.sublist(startIndex, endIndex);
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _updateCurrentPageItems();
    });
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.noItemsMessage ?? AppStrings.noGamesFound,
          style: const TextStyle(color: AppColors.textLight, fontSize: 18),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: widget.itemExtent > 0 
              ? ListView.builder(
                  controller: _scrollController,
                  padding: widget.padding,
                  itemCount: _currentPageItems.length,
                  itemExtent: widget.itemExtent,
                  itemBuilder: (context, index) => widget.itemBuilder(
                    context, 
                    _currentPageItems[index], 
                    ((_currentPage - 1) * widget.pageSize) + index
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: widget.padding,
                  itemCount: _currentPageItems.length,
                  itemBuilder: (context, index) => widget.itemBuilder(
                    context, 
                    _currentPageItems[index], 
                    ((_currentPage - 1) * widget.pageSize) + index
                  ),
                ),
        ),
        if (_totalPages > 1 && widget.showPageNumbers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildPaginationControls(),
          ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.first_page, color: AppColors.primary),
          onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
          splashRadius: 20,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primary),
          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          splashRadius: 20,
        ),
        const SizedBox(width: 8),
        _buildPageNumbers(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.primary),
          onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
          splashRadius: 20,
        ),
        IconButton(
          icon: const Icon(Icons.last_page, color: AppColors.primary),
          onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildPageNumbers() {
    if (_totalPages <= 7) {
      // Show all page numbers if total pages are 7 or less
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_totalPages, (index) {
          return _buildPageButton(index + 1);
        }),
      );
    } else {
      // Show limited page numbers with ellipsis for many pages
      List<Widget> pageButtons = [];
      
      // Always show first page
      pageButtons.add(_buildPageButton(1));
      
      // Add ellipsis if current page is not near the start
      if (_currentPage > 3) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: AppColors.textLight)),
        ));
      }
      
      // Pages around current page
      for (int i = _currentPage - 1; i <= _currentPage + 1; i++) {
        if (i > 1 && i < _totalPages) {
          pageButtons.add(_buildPageButton(i));
        }
      }
      
      // Add ellipsis if current page is not near the end
      if (_currentPage < _totalPages - 2) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: AppColors.textLight)),
        ));
      }
      
      // Always show last page
      pageButtons.add(_buildPageButton(_totalPages));
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: pageButtons,
      );
    }
  }

  Widget _buildPageButton(int pageNum) {
    final isCurrentPage = pageNum == _currentPage;
    return InkWell(
      onTap: isCurrentPage ? null : () => _goToPage(pageNum),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isCurrentPage ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrentPage ? AppColors.primary : AppColors.textSubtle,
          ),
        ),
        child: Center(
          child: Text(
            '$pageNum',
            style: TextStyle(
              color: isCurrentPage ? AppColors.darkBackground : AppColors.textLight,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}