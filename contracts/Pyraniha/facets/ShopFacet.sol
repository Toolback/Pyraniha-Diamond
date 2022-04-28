// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {Modifiers, AppStorage, ItemType, Cycle} from "../libraries/LibAppStorage.sol";
import {LibPyraniha} from "../libraries/LibPyraniha.sol";
// import "hardhat/console.sol";
import {IERC20} from "../../shared/interfaces/IERC20.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";
import {LibERC1155} from "../../shared/libraries/LibERC1155.sol";
import {LibItems} from "../libraries/LibItems.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import {LibERC1155Marketplace} from "../libraries/LibERC1155Marketplace.sol";

contract ShopFacet is Modifiers {
    event MintEggs(
        address indexed _from,
        address indexed _to,
        // uint256 indexed _batchId,
        uint256 _tokenId,
        uint256 _numPyranihasToPurchase,
        uint256 _cycleId
    );

    event BuyEggs(
        address indexed _from,
        address indexed _to,
        // uint256 indexed _batchId,
        uint256 _tokenId,
        uint256 _numPyranihasToPurchase,
        uint256 _totalPrice
    );

    event MintCompany(
        address indexed _from,
        address indexed _to,
        // uint256 indexed _batchId,
        uint256 _tokenId,
        uint256 _numPyranihasToPurchase,
        uint256 _cycleId
    );

    event BuyCompany(
        address indexed _from,
        address indexed _to,
        // uint256 indexed _batchId,
        uint256 _tokenId,
        uint256 _numPyranihasToPurchase,
        uint256 _totalPrice
    );

    event PurchaseItemsWithGhst(address indexed _buyer, address indexed _to, uint256[] _itemIds, uint256[] _quantities, uint256 _totalPrice);
    event PurchaseTransferItemsWithGhst(address indexed _buyer, address indexed _to, uint256[] _itemIds, uint256[] _quantities, uint256 _totalPrice);

    event PurchaseItemsWithVouchers(address indexed _buyer, address indexed _to, uint256[] _itemIds, uint256[] _quantities);

    ///@notice Allow an address to purchase a portal
    ///@dev Only portals from haunt 1 can be purchased via the contract
    ///@param _to Address to send the portal once purchased
    ///@param _ghst The amount of GHST the buyer is willing to pay //calculation will be done to know how much portal he recieves based on the haunt's portal price
    function buyEggs(address _to, uint256 _ghst) external {
        uint256 currentCycleId = s.currentCycleId;
        require(currentCycleId == 1, "ShopFacet: Can only purchase from Cycle 1");
        Cycle storage cycle = s.cycles[currentCycleId];
        uint256 price = cycle.eggPrice;
        require(_ghst >= price, "Not enough GHST to buy eggs");
        uint256[3] memory tiers;
        tiers[0] = price * 5;
        tiers[1] = tiers[0] + (price * 2 * 10);
        tiers[2] = tiers[1] + (price * 3 * 10);
        require(_ghst <= tiers[2], "Can't buy more than 25");
        address sender = LibMeta.msgSender();
        uint256 numToPurchase;
        uint256 totalPrice;
        if (_ghst <= tiers[0]) {
            numToPurchase = _ghst / price;
            totalPrice = numToPurchase * price;
        } else {
            if (_ghst <= tiers[1]) {
                numToPurchase = (_ghst - tiers[0]) / (price * 2);
                totalPrice = tiers[0] + (numToPurchase * (price * 2));
                numToPurchase += 5;
            } else {
                numToPurchase = (_ghst - tiers[1]) / (price * 3);
                totalPrice = tiers[1] + (numToPurchase * (price * 3));
                numToPurchase += 15;
            }
        }
        uint256 cycleCount = cycle.totalCount + numToPurchase;
        require(cycleCount <= cycle.cycleMaxSize, "ShopFacet: Exceeded max number of pyranihas for this cycle");
        s.cycles[currentCycleId].totalCount = uint24(cycleCount);
        uint32 tokenId = s.tokenIdCounter;
        emit BuyEggs(sender, _to, tokenId, numToPurchase, totalPrice);
        for (uint256 i; i < numToPurchase; i++) {
            s.pyranihas[tokenId].owner = _to;
            s.pyranihas[tokenId].cycleId = uint16(currentCycleId);
            s.tokenIdIndexes[tokenId] = s.tokenIds.length;
            s.tokenIds.push(tokenId);
            s.ownerTokenIdIndexes[_to][tokenId] = s.ownerTokenIds[_to].length;
            s.ownerTokenIds[_to].push(tokenId);
            emit LibERC721.Transfer(address(0), _to, tokenId);
            tokenId++;
        }
        s.tokenIdCounter = tokenId;
        // LibAavegotchi.verify(tokenId);
        LibPyraniha.purchase(sender, totalPrice);
    }

    ///@notice Allow an item manager to mint neew portals
    ///@dev Will throw if the max number of portals for the current haunt has been reached
    ///@param _to The destination of the minted portals
    ///@param _amount the amunt of portals to mint
    function mintEggs(address _to, uint256 _amount) external onlyItemManager {
        uint256 currentCycleId = s.currentCycleId;
        Cycle storage cycle = s.cycles[currentCycleId];
        address sender = LibMeta.msgSender();
        uint256 cycleCount = cycle.totalCount + _amount;
        require(cycleCount <= cycle.cycleMaxSize, "ShopFacet: Exceeded max number of pyranihas for this cycle");
        s.cycles[currentCycleId].totalCount = uint24(cycleCount);
        uint32 tokenId = s.tokenIdCounter;
        emit MintPortals(sender, _to, tokenId, _amount, currentCycleId);
        for (uint256 i; i < _amount; i++) {
            s.pyranihas[tokenId].owner = _to;
            s.pyranihas[tokenId].cycleId = uint16(currentCycleId);
            s.tokenIdIndexes[tokenId] = s.tokenIds.length;
            s.tokenIds.push(tokenId);
            s.ownerTokenIdIndexes[_to][tokenId] = s.ownerTokenIds[_to].length;
            s.ownerTokenIds[_to].push(tokenId);
            emit LibERC721.Transfer(address(0), _to, tokenId);
            tokenId++;
        }
        s.tokenIdCounter = tokenId;
    }

    ///@notice Allow an address to purchase a company
    ///@dev Only companys from haunt 1 can be purchased via the contract
    ///@param _to Address to send the company once purchased
    ///@param _ghst The amount of GHST the buyer is willing to pay //calculation will be done to know how much portal he recieves based on the haunt's portal price
    function buyCompanies(address _to, uint256 _typeId ) external {
        uint256 currentUnionId = s.currentUnionId;
        require(currentUnionId == 1, "ShopFacet: Can only purchase from Union 1");
        Union storage union = s.unions[currentUnionId];
        uint256 price = union.companyPrice;
        require(msg.value == price, "Not enough GHST to buy companys");
        address sender = LibMeta.msgSender();

        // uint256[3] memory tiers;
        // tiers[0] = price * 5;
        // tiers[1] = tiers[0] + (price * 2 * 10);
        // tiers[2] = tiers[1] + (price * 3 * 10);
        // require(_ghst <= tiers[2], "Can't buy more than 25");
        // address sender = LibMeta.msgSender();
        // uint256 numToPurchase;
        // uint256 totalPrice;
        // if (_ghst <= tiers[0]) {
        //     numToPurchase = _ghst / price;
        //     totalPrice = numToPurchase * price;
        // } else {
        //     if (_ghst <= tiers[1]) {
        //         numToPurchase = (_ghst - tiers[0]) / (price * 2);
        //         totalPrice = tiers[0] + (numToPurchase * (price * 2));
        //         numToPurchase += 5;
        //     } else {
        //         numToPurchase = (_ghst - tiers[1]) / (price * 3);
        //         totalPrice = tiers[1] + (numToPurchase * (price * 3));
        //         numToPurchase += 15;
        //     }
        // }
        uint256 unionCount = union.totalCount + 1;
        require(unionCount <= union.unionMaxSize, "ShopFacet: Exceeded max number of companies for this union");
        s.unions[currentUnionId].totalCount = uint24(unionCount);
        uint32 tokenId = s.companyIdCounter;
        emit BuyCompany(sender, _to, tokenId, 1, msg.value);
        // for (uint256 i; i < numToPurchase; i++) {
            s.companies[tokenId].owner = _to;
            s.companies[tokenId].creator = _to;
            s.companies[tokenId].uId = tokenId;
            s.companies[tokenId].unionId = uint16(currentUnionId);
            s.companyIdIndexes[tokenId] = s.companyIds.length;
            s.companyIds.push(tokenId);
            s.ownerCompanyIdIndexes[_to][tokenId] = s.ownerCompanyIds[_to].length;
            s.ownerCompanyIds[_to].push(tokenId);
            ////
            uint256 itemTypesLength = s.itemTypes.length;
            require(itemTypesLength > _typeId, "ShopFacet: Item type does not exist");
            uint256 totalQuantity = s.itemTypes[itemId].totalQuantity + 1;
            require(totalQuantity <= s.itemTypes[itemId].maxQuantity, "ShopFacet: Total company type quantity exceeds max quantity right now");
            
            LibItems.addToOwner(_to, _typeId, 1);
            s.itemTypes[_typeId].totalQuantity = totalQuantity;
            ////
            emit LibERC1155.TransferBatch(sender, address(0), _to, _itemIds, _quantities);
            LibERC1155.onERC1155BatchReceived(sender, address(0), _to, _itemIds, _quantities, "");
            tokenId++;
        // }
        s.companyIdCounter = tokenId;
        // LibAavegotchi.verify(tokenId);
        LibPyraniha.purchase(sender, totalPrice);
    }


    ///@notice Allow an item manager to mint neew portals
    ///@dev Will throw if the max number of portals for the current haunt has been reached
    ///@param _to The destination of the minted portals
    ///@param _amount the amunt of portals to mint
    function mintCompanies(address _to, uint256 _amount) external onlyItemManager {
        uint256 currentUnionId = s.currentUnionId;
        Union storage union = s.unions[currentUnionId];
        address sender = LibMeta.msgSender();
        uint256 unionCount = union.totalCount + _amount;
        require(unionCount <= union.unionMaxSize, "ShopFacet: Exceeded max number of companies for this union");
        s.unions[currentUnionId].totalCount = uint24(unionCount);
        uint32 tokenId = s.tokenIdCounter;
        emit MintPortals(sender, _to, tokenId, _amount, currentUnionId);
        for (uint256 i; i < _amount; i++) {
            s.companies[tokenId].owner = _to;
            s.companies[tokenId].unionId = uint16(currentUnionId);
            s.companyIdIndexes[tokenId] = s.companyIds.length;
            s.companyIds.push(tokenId);
            s.ownerCompanyIdIndexes[_to][tokenId] = s.ownerCompanyIds[_to].length;
            s.ownerCompanyIds[_to].push(tokenId);
            emit LibERC721.Transfer(address(0), _to, tokenId);
            tokenId++;
        }
        s.tokenIdCounter = tokenId;
    }

    ///@notice Allow an address to purchase multiple items
    ///@dev Buying an item typically mints it, it will throw if an item has reached its maximum quantity
    ///@param _to Address to send the items once purchased
    ///@param _itemIds The identifiers of the items to be purchased
    ///@param _quantities The quantities of each item to be bought
    function purchaseItemsWithGhst(
        address _to,
        uint256[] calldata _itemIds,
        uint256[] calldata _quantities
    ) external {
        address sender = LibMeta.msgSender();
        require(_itemIds.length == _quantities.length, "ShopFacet: _itemIds not same length as _quantities");
        uint256 totalPrice;
        for (uint256 i; i < _itemIds.length; i++) {
            uint256 itemId = _itemIds[i];
            uint256 quantity = _quantities[i];
            ItemType storage itemType = s.itemTypes[itemId];
            require(itemType.canPurchaseWithGhst, "ShopFacet: Can't purchase item type with GHST");
            uint256 totalQuantity = itemType.totalQuantity + quantity;
            require(totalQuantity <= itemType.maxQuantity, "ShopFacet: Total item type quantity exceeds max quantity");
            itemType.totalQuantity = totalQuantity;
            totalPrice += quantity * itemType.ghstPrice;
            LibItems.addToOwner(_to, itemId, quantity);
        }
        uint256 ghstBalance = IERC20(s.ghstContract).balanceOf(sender);
        require(ghstBalance >= totalPrice, "ShopFacet: Not enough GHST!");
        emit PurchaseItemsWithGhst(sender, _to, _itemIds, _quantities, totalPrice);
        emit LibERC1155.TransferBatch(sender, address(0), _to, _itemIds, _quantities);
        LibPyraniha.purchase(sender, totalPrice);
        LibERC1155.onERC1155BatchReceived(sender, address(0), _to, _itemIds, _quantities, "");
    }

    ///@notice Allow an address to purchase multiple items after they have been minted
    ///@dev Only one item per transaction can be purchased from the Diamond contract
    ///@param _to Address to send the items once purchased
    ///@param _itemIds The identifiers of the items to be purchased
    ///@param _quantities The quantities of each item to be bought

    function purchaseTransferItemsWithGhst(
        address _to,
        uint256[] calldata _itemIds,
        uint256[] calldata _quantities
    ) external {
        require(_to != address(0), "ShopFacet: Can't transfer to 0 address");
        require(_itemIds.length == _quantities.length, "ShopFacet: ids not same length as values");
        address sender = LibMeta.msgSender();
        address from = address(this);
        uint256 totalPrice;
        for (uint256 i; i < _itemIds.length; i++) {
            uint256 itemId = _itemIds[i];
            uint256 quantity = _quantities[i];
            require(quantity == 1, "ShopFacet: Can only purchase 1 of an item per transaction");
            ItemType storage itemType = s.itemTypes[itemId];
            require(itemType.canPurchaseWithGhst, "ShopFacet: Can't purchase item type with GHST");
            totalPrice += quantity * itemType.ghstPrice;
            LibItems.removeFromOwner(from, itemId, quantity);
            LibItems.addToOwner(_to, itemId, quantity);
            LibERC1155Marketplace.updateERC1155Listing(address(this), itemId, from);
        }
        uint256 ghstBalance = IERC20(s.ghstContract).balanceOf(sender);
        require(ghstBalance >= totalPrice, "ShopFacet: Not enough GHST!");
        emit LibERC1155.TransferBatch(sender, from, _to, _itemIds, _quantities);
        emit PurchaseTransferItemsWithGhst(sender, _to, _itemIds, _quantities, totalPrice);
        LibAavegotchi.purchase(sender, totalPrice);
        LibERC1155.onERC1155BatchReceived(sender, from, _to, _itemIds, _quantities, "");
    }
}
