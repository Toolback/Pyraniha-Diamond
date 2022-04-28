// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {LibPyraniha, PyranihaInfo, NUMERIC_TRAITS_NUM, PyranihaCollateralTypeInfo, EggPyranihaTraitsIO, InternalEggPyranihaTraitsIO, EGG_PYRANIHAS_NUM} from "../libraries/LibPyraniha.sol";

import {LibAppStorage} from "../libraries/LibAppStorage.sol";

import {IERC20} from "../../shared/interfaces/IERC20.sol";
import {LibStrings} from "../../shared/libraries/LibStrings.sol";
import {Modifiers, Cycle, Pyraniha} from "../libraries/LibAppStorage.sol";
import {LibERC20} from "../../shared/libraries/LibERC20.sol";
import {CollateralEscrow} from "../CollateralEscrow.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import {LibERC721Marketplace} from "../libraries/LibERC721Marketplace.sol";

contract PyranihaGameFacet is Modifiers {
    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.

    event ClaimPyraniha(uint256 indexed _tokenId);

    event SetPyranihaName(uint256 indexed _tokenId, string _oldName, string _newName);

    event SetBatchId(uint256 indexed _batchId, uint256[] tokenIds);

    event SpendSkillpoints(uint256 indexed _tokenId, int16[4] _values);

    event LockPyraniha(uint256 indexed _tokenId, uint256 _time);
    event UnLockPyraniha(uint256 indexed _tokenId, uint256 _time);

    ///@notice Check if a string `_name` has not been assigned to another NFT
    ///@param _name Name to check
    ///@return available_ True if the name has not been taken, False otherwise
    function pyranihaNameAvailable(string calldata _name) external view returns (bool available_) {
        available_ = s.pyranihaNamesUsed[LibPyraniha.validateAndLowerName(_name)];
    }

    ///@notice Check the latest Haunt identifier and details
    ///@return hauntId_ The latest haunt identifier
    ///@return haunt_ A struct containing the details about the latest haunt`

    function currentCycle() external view returns (uint256 cycleId_, Haunt memory cycle_) {
        cycleId_ = s.currentCycleId;
        cycle_ = s.cycles[cycleId_];
    }

    struct RevenueSharesIO {
        address burnAddress;
        address daoAddress;
        address rarityFarming;
        address pixelCraft;
    }

    ///@notice Check all addresses relating to revenue deposits including the burn address
    ///@return RevenueSharesIO A struct containing all addresses relating to revenue deposits
    function revenueShares() external view returns (RevenueSharesIO memory) {
        return RevenueSharesIO(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF, s.daoTreasury, s.rarityFarming, s.pixelCraft);
    }

    ///@notice Query all details associated with an NFT like collateralType,numericTraits e.t.c
    ///@param _tokenId Identifier of the NFT to query
    ///@return portalAavegotchiTraits_ A struct containing all details about the NFT with identifier `_tokenId`

    function eggPyranihaTraits(uint256 _tokenId)
        external
        view
        returns (EggPyranihaTraitsIO[EGG_PYRANIHAS_NUM] memory eggPyranihaTraits_)
    {
        eggPyranihaTraits_ = LibPyraniha.eggPyranihaTraits(_tokenId);
    }

    ///@notice Query the $GHST token address
    ///@return contract_ the deployed address of the $GHST token contract
    function ghstAddress() external view returns (address contract_) {
        contract_ = s.ghstContract;
    }

    ///@notice Query the numeric traits of an NFT
    ///@dev Only valid for claimed Aavegotchis
    ///@param _tokenId The identifier of the NFT to query
    ///@return numericTraits_ A six-element array containing integers,each representing the traits of the NFT with identifier `_tokenId`
    function getNumericTraits(uint256 _tokenId) external view returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_) {
        numericTraits_ = LibPyraniha.getNumericTraits(_tokenId);
    }

    ///@notice Query the available skill points that can be used for an NFT
    ///@dev Will throw if the amount of skill points available is greater than or equal to the amount of skill points which have been used
    ///@param _tokenId The identifier of the NFT to query
    ///@return   An unsigned integer which represents the available skill points of an NFT with identifier `_tokenId`
    function availableSkillPoints(uint256 _tokenId) public view returns (uint256) {
        uint256 skillPoints = _calculateSkillPoints(_tokenId);
        uint256 usedSkillPoints = s.pyranihas[_tokenId].usedSkillPoints;
        require(skillPoints >= usedSkillPoints, "PyranihaGameFacet: Used skill points is greater than skill points");
        return skillPoints - usedSkillPoints;
    }

    function _calculateSkillPoints(uint256 _tokenId) internal view returns (uint256) {
        uint256 level = LibPyraniha.pyranihaLevel(s.pyranihas[_tokenId].experience);
        uint256 skillPoints = (level / 3);

        uint256 claimTime = s.pyranihas[_tokenId].claimTime;
        uint256 ageDifference = block.timestamp - claimTime;
        return skillPoints + _skillPointsByAge(ageDifference);
    }

    function _skillPointsByAge(uint256 _age) internal pure returns (uint256) {
        uint256 skillPointsByAge = 0;
        uint256[10] memory fibSequence = [uint256(1), 2, 3, 5, 8, 13, 21, 34, 55, 89];
        for (uint256 i = 0; i < fibSequence.length; i++) {
            if (_age > fibSequence[i] * 2300000) {
                skillPointsByAge++;
            } else {
                break;
            }
        }
        return skillPointsByAge;
    }

    ///@notice Calculate level given the XP(experience points)
    ///@dev Only valid for claimed Aavegotchis
    ///@param _experience the current XP gathered by an NFT
    ///@return level_ The level of an NFT with experience `_experience`
    function pyranihaLevel(uint256 _experience) external pure returns (uint256 level_) {
        level_ = LibPyraniha.pyranihaLevel(_experience);
    }

    ///@notice Calculate the XP needed for an NFT to advance to the next level
    ///@dev Only valid for claimed Aavegotchis
    ///@param _experience The current XP points gathered by an NFT
    ///@return requiredXp_ The XP required for the NFT to move to the next level
    function xpUntilNextLevel(uint256 _experience) external pure returns (uint256 requiredXp_) {
        requiredXp_ = LibPyraniha.xpUntilNextLevel(_experience);
    }

    ///@notice Compute the rarity multiplier of an NFT
    ///@dev Only valid for claimed Aavegotchis
    ///@param _numericTraits An array of six integers each representing a numeric trait of an NFT
    ///return multiplier_ The rarity multiplier of an NFT with numeric traits `_numericTraits`
    function rarityMultiplier(int16[NUMERIC_TRAITS_NUM] memory _numericTraits) external pure returns (uint256 multiplier_) {
        multiplier_ = LibPyraniha.rarityMultiplier(_numericTraits);
    }

    ///@notice Calculates the base rarity score, including collateral modifier
    ///@dev Only valid for claimed Aavegotchis
    ///@param _numericTraits An array of six integers each representing a numeric trait of an NFT
    ///@return rarityScore_ The base rarity score of an NFT with numeric traits `_numericTraits`
    function baseRarityScore(int16[NUMERIC_TRAITS_NUM] memory _numericTraits) external pure returns (uint256 rarityScore_) {
        rarityScore_ = LibPyraniha.baseRarityScore(_numericTraits);
    }

    ///@notice Check the modified traits and rarity score of an NFT(as a result of equipped wearables)
    ///@dev Only valid for claimed Aavegotchis
    ///@param _tokenId Identifier of the NFT to query
    ///@return numericTraits_ An array of six integers each representing a numeric trait(modified) of an NFT with identifier `_tokenId`
    ///@return rarityScore_ The modified rarity score of an NFT with identifier `_tokenId`
    //Only valid for claimed Aavegotchis
    function modifiedTraitsAndRarityScore(uint256 _tokenId)
        external
        view
        returns (int16[NUMERIC_TRAITS_NUM] memory numericTraits_, uint256 rarityScore_)
    {
        (numericTraits_, rarityScore_) = LibPyraniha.modifiedTraitsAndRarityScore(_tokenId);
    }

    ///@notice Check the kinship of an NFT
    ///@dev Only valid for claimed Aavegotchis
    ///@dev Default kinship value is 50
    ///@param _tokenId Identifier of the NFT to query
    ///@return score_ The kinship of an NFT with identifier `_tokenId`
    function kinship(uint256 _tokenId) external view returns (uint256 score_) {
        score_ = LibPyraniha.kinship(_tokenId);
    }

    struct TokenIdsWithKinship {
        uint256 tokenId;
        uint256 kinship;
        uint256 lastInteracted;
    }

    ///@notice Query the tokenId,kinship and lastInteracted values of a set of NFTs belonging to an address
    ///@dev Will throw if `_count` is greater than the number of NFTs owned by `_owner`
    ///@param _owner Address to query
    ///@param _count Number of NFTs to check
    ///@param _skip Number of NFTs to skip while querying
    ///@param all If true, query all NFTs owned by `_owner`; if false, query `_count` NFTs owned by `_owner`
    ///@return tokenIdsWithKinship_ An array of structs where each struct contains the `tokenId`,`kinship`and `lastInteracted` of each NFT
    function tokenIdsWithKinship(
        address _owner,
        uint256 _count,
        uint256 _skip,
        bool all
    ) external view returns (TokenIdsWithKinship[] memory tokenIdsWithKinship_) {
        uint32[] memory tokenIds = s.ownerTokenIds[_owner];
        uint256 length = all ? tokenIds.length : _count;
        tokenIdsWithKinship_ = new TokenIdsWithKinship[](length);

        if (!all) {
            require(_skip + _count <= tokenIds.length, "gameFacet: Owner does not have up to that amount of tokens");
        }

        for (uint256 i; i < length; i++) {
            uint256 offset = i + _skip;
            uint32 tokenId = tokenIds[offset];
            if (s.pyranihas[tokenId].status == 3) {
                tokenIdsWithKinship_[i].tokenId = tokenId;
                tokenIdsWithKinship_[i].kinship = LibPyraniha.kinship(tokenId);
                tokenIdsWithKinship_[i].lastInteracted = s.pyranihas[tokenId].lastInteracted;
            }
        }
    }

    ///@notice Allows the owner of an NFT(Portal) to claim an Aavegotchi provided it has been unlocked
    ///@dev Will throw if the Portal(with identifier `_tokenid`) has not been opened(Unlocked) yet
    ///@dev If the NFT(Portal) with identifier `_tokenId` is listed for sale on the baazaar while it is being unlocked, that listing is cancelled
    ///@param _tokenId The identifier of NFT to claim an Aavegotchi from
    ///@param _option The index of the aavegotchi to claim(1-10)
    ///@param _stakeAmount Minimum amount of collateral tokens needed to be sent to the new aavegotchi escrow contract
    function claimPyraniha(
        uint256 _tokenId,
        uint256 _option,
        uint256 _stakeAmount
    ) external onlyUnlocked(_tokenId) onlyPyranihaOwner(_tokenId) {
        Pyraniha storage pyraniha = s.pyranihas[_tokenId];
        require(pyraniha.status == LibPyraniha.STATUS_OPEN_PORTAL, "PyranihaGameFacet: Portal not open");
        require(_option < EGG_PYRANIHAS_NUM, "PyranihaGameFacet: Only 10 Pyraniha options available");
        uint256 randomNumber = s.tokenIdToRandomNumber[_tokenId];
        uint256 cycleId = s.pyranihas[_tokenId].cycleId;

        InternalEggPyranihaTraitsIO memory option = LibPyraniha.singleEggPyranihaTraits(cycleId, randomNumber, _option);
        pyraniha.randomNumber = option.randomNumber;
        pyraniha.numericTraits = option.numericTraits;
        pyraniha.collateralType = option.collateralType;
        pyraniha.minimumStake = option.minimumStake;
        pyraniha.lastInteracted = uint40(block.timestamp - 12 hours);
        pyraniha.interactionCount = 50;
        pyraniha.claimTime = uint40(block.timestamp);

        require(_stakeAmount >= option.minimumStake, "PyranihaGameFacet: _stakeAmount less than minimum stake");

        pyraniha.status = LibPyraniha.STATUS_PYRANIHA;
        emit ClaimPyraniha(_tokenId);

        address escrow = address(new CollateralEscrow(option.collateralType));
        pyraniha.escrow = escrow;
        address owner = LibMeta.msgSender();
        LibERC20.transferFrom(option.collateralType, owner, escrow, _stakeAmount);
        LibERC721Marketplace.cancelERC721Listing(address(this), _tokenId, owner);
    }

    ///@notice Allows the owner of a NFT to set a name for it
    ///@dev only valid for claimed aavegotchis
    ///@dev Will throw if the name has been used for another claimed aavegotchi
    ///@param _tokenId the identifier if the NFT to name
    ///@param _name Preferred name to give the claimed aavegotchi

    function setPyranihaName(uint256 _tokenId, string calldata _name) external onlyUnlocked(_tokenId) onlyPyranihaOwner(_tokenId) {
        require(s.pyranihas[_tokenId].status == LibPyraniha.STATUS_PYRANIHA, "PyranihaGameFacet: Must claim Pyraniha before setting name");
        string memory lowerName = LibPyraniha.validateAndLowerName(_name);
        string memory existingName = s.pyranihas[_tokenId].name;
        if (bytes(existingName).length > 0) {
            delete s.pyranihaNamesUsed[LibPyraniha.validateAndLowerName(existingName)];
        }
        require(!s.pyranihaNamesUsed[lowerName], "PyranihaGameFacet: Pyraniha name used already");
        s.pyranihaNamesUsed[lowerName] = true;
        s.pyranihas[_tokenId].name = _name;
        emit SetPyranihaName(_tokenId, existingName, _name);
    }

    ///@notice Allow the owner of an NFT to interact with them.thereby increasing their kinship(petting)
    ///@dev only valid for claimed aavegotchis
    ///@dev Kinship will only increase if the lastInteracted minus the current time is greater than or equal to 12 hours
    ///@param _tokenIds An array containing the token identifiers of the claimed aavegotchis that are to be interacted with
    function interact(uint256[] calldata _tokenIds) external {
        address sender = LibMeta.msgSender();
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            address owner = s.pyranihas[tokenId].owner;

            //If the owner is the bridge, anyone can pet the gotchis inside
            if (owner != address(this)) {
                require(
                    sender == owner || s.operators[owner][sender] || s.approved[tokenId] == sender || s.petOperators[owner][sender],
                    "PyranihaGameFacet: Not owner of token or approved"
                );
            }

            require(s.pyranihas[tokenId].status == LibPyraniha.STATUS_PYRANIHA, "LibPyraniha: Only valid for Pyraniha");
            LibPyraniha.interact(tokenId);
        }
    }

    ///@notice Allow the owner of an NFT to spend skill points for it(basically to boost the numeric traits of that NFT)
    ///@dev only valid for claimed aavegotchis
    ///@param _tokenId The identifier of the NFT to spend the skill points on
    ///@param _values An array of four integers that represent the values of the skill points
    function spendSkillPoints(uint256 _tokenId, int16[4] calldata _values) external onlyUnlocked(_tokenId) onlyPyranihaOwner(_tokenId) {
        //To test (Dan): Prevent underflow (is this ok?), see require below
        uint256 totalUsed;
        for (uint256 index; index < _values.length; index++) {
            totalUsed += LibAppStorage.abs(_values[index]);

            s.pyranihas[_tokenId].numericTraits[index] += _values[index];
        }
        // handles underflow
        require(availableSkillPoints(_tokenId) >= totalUsed, "PyranihaGameFacet: Not enough skill points");
        //Increment used skill points
        s.pyranihas[_tokenId].usedSkillPoints += totalUsed;
        emit SpendSkillpoints(_tokenId, _values);
    }
}
