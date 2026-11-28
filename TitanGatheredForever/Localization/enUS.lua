local _, ns = ...
ns.L = {
    title = 'Titan Gathered Forever',
    unknown = 'unknown',
    loading = 'Item %d (loading)',
    bankObserved = 'Bank last observed: %s',
    showZero = 'Show items with zero counts',
    itemTooltips = 'Show item use and inventory tooltips',
    counts = 'Bags / Bank / Total',
    hint = 'Right-click for settings. Mouse wheel changes page.',
    noItems = 'No matching owned materials. Change categories or show zero counts.',
    unsupported = 'Titan Gathered Forever requires WoW Forever interface 16001.',
    auctionMissing = 'The auction house features (price scans, the Sell tab undercut, posting history and auction sales) '
        .. 'come with the Auction house module, Titan Gathered Forever: Auction house. Install it, update it to 0.6.0 or newer, or enable it in the AddOns '
        .. 'list. Data recorded before is kept.',
}
-- Said wherever an auction feature is asked for without the Auction house module.
ns.AUCTION_MODULE_MISSING = ns.L.auctionMissing
