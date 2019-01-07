pragma solidity ^0.4.25;

import "OathForge.sol";
import "ERC721.sol";
import "ERC20.sol";
import "math/SafeMath.sol";

/// @title RiftPact: OathForge Token Fracturizer
/// @author GuildCrypt
contract RiftPact is ERC20 {

  using SafeMath for uint256;

  address private _daiAddress; // TODO: Hard code; Left variable for testability
  address private _oathForgeAddress; // TODO: Hard code; Left variable for testability
  uint256 private _minAuctionCompleteWait = 604800; // 7 days in seconds

  uint256 private _oathForgeTokenId;
  uint256 private _auctionAllowedAt;

  uint256 private _auctionStartedAt;
  uint256 private _auctionCompletedAt;
  uint256 private _minBidDeltaPerunNumerator = 5;
  uint256 private _minBidDeltaPerunDenominator = 1000;

  uint256 private _minBid = 1;
  uint256 private _topBid;
  address private _topBidder;
  uint256 private _topBidSubmittedAt;

  /// @param __oathForgeTokenId The id of the token on the OathForge contract
  /// @param __auctionAllowedAt The timestamp at which anyone can start an auction
  /// @param __daiAddress The address of the DAI contract. **TODO: Hard code. Left Variable for testability.**
  /// @param __oathForgeAddress The address of the OathForge contract **TODO: Hard code. Left Variable for testability.**
  constructor(
    uint256 __oathForgeTokenId,
    uint256 __auctionAllowedAt,
    address __daiAddress, // TODO: Hard code; Left variable for testability
    address __oathForgeAddress // TODO: Hard code; Left variable for testability
  ) public {
    _oathForgeTokenId = __oathForgeTokenId;
    _auctionAllowedAt = __auctionAllowedAt;

    _daiAddress = __daiAddress; // TODO: Hard code; Left variable for testability
    _oathForgeAddress = __oathForgeAddress; // TODO: Hard code; Left variable for testability

    _mint(msg.sender, 10000);
  }

  /// @dev Returns the DAI contract address.
  function daiAddress() external view returns(address) {
    return _daiAddress;
  }

  /// @dev Returns the OathForge contract address.
  function oathForgeAddress() external view returns(address) {
    return _oathForgeAddress;
  }

  /// @dev Returns the OathForge token id. **Does not imply RiftPact has ownership over token.**
  function oathForgeTokenId() external view returns(uint256) {
    return _oathForgeTokenId;
  }

  /// @dev Returns the timestamp at which anyone can start an auction by calling [`startAuction()`](#startAuction())
  function auctionAllowedAt() external view returns(uint256) {
    return _auctionAllowedAt;
  }

  /// @dev Returns the minimum bid in attoDAI (10^-18 DAI).
  function minBid() external view returns(uint256) {
    return _minBid;
  }

  /// @dev Returns the timestamp at which an auction was started or 0 if no auction has been started
  function auctionStartedAt() external view returns(uint256) {
    return _auctionStartedAt;
  }

  /// @dev Returns the timestamp at which an auction was completed or 0 if no auction has been completed
  function auctionCompletedAt() external view returns(uint256) {
    return _auctionCompletedAt;
  }

  /// @dev Returns the top bid or 0 if no bids have been placed
  function topBid() external view returns(uint256) {
    return _topBid;
  }

  /// @dev Returns the top bidder or `address(0)` if no bids have been placed
  function topBidder() external view returns(address) {
    return _topBidder;
  }

  /// @dev Start an auction
  function startAuction() external {
    require(_auctionStartedAt == 0);
    require(
      (now >= _auctionAllowedAt)
      || (OathForge(_oathForgeAddress).sunsetInitiatedAt(_oathForgeTokenId) > 0)
    );
    _auctionStartedAt = now;
  }

  /// @dev Submit a bid. Must have sufficient funds approved in `DAI` contract (bid * totalSupply).
  /// @param bid Bid in attoDAI (10^-18 DAI)
  function submitBid(uint256 bid) external {
    require(_auctionStartedAt > 0);
    require(_auctionCompletedAt == 0);
    require (bid >= _minBid);
    if (_topBidder != address(0)) {
      require(ERC20(_daiAddress).transfer(_topBidder, _topBid * totalSupply()));
    }
    require(ERC20(_daiAddress).transferFrom(msg.sender, address(this), bid * totalSupply()));
    _topBid = bid;
    _topBidder = msg.sender;
    _topBidSubmittedAt = now;

    uint256 minBidDeltaNumerator = bid * _minBidDeltaPerunNumerator;
    uint256 minBidRoundUp = 0;

    if(minBidDeltaNumerator % _minBidDeltaPerunDenominator > 0) {
      minBidRoundUp = 1;
    }

    _minBid =  (
      bid + minBidRoundUp + (
      (
        minBidDeltaNumerator / _minBidDeltaPerunDenominator
      )
     )
    );
  }

  /// @dev Complete auction
  function completeAuction() external {
    require(_auctionCompletedAt == 0);
    require(_topBid > 0);
    require((_topBidSubmittedAt + _minAuctionCompleteWait) < now);
    _auctionCompletedAt = now;
  }

  /// @dev Payout `dai` after auction completed
  function payout() external {
    require(balanceOf(msg.sender) > 0);
    require(_auctionCompletedAt > 0);
    require(ERC20(_daiAddress).transfer(msg.sender, balanceOf(msg.sender) * _topBid));
    _burn(msg.sender, balanceOf(msg.sender));
  }


}
