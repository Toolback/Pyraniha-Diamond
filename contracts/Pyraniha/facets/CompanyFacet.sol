pragma solidity ^0.8.8;


import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibPyraniha, PyranihaInfo} from "../libraries/LibPyraniha.sol";
import {LibCompany, CompanyInfo} from "../libraries/LibCompany.sol";




import {LibStrings} from "../../shared/libraries/LibStrings.sol";
// import "hardhat/console.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import {LibERC721Marketplace} from "../libraries/LibERC721Marketplace.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";
import {IERC721TokenReceiver} from "../../shared/interfaces/IERC721TokenReceiver.sol";

import {LibDiamond} from "../../shared/libraries/LibDiamond.sol";
import {LibCompany} from "../libraries/LibCompany.sol";

contract CompanyFacet {
  AppStorage internal s;

    ///@notice Query all details relating to an NFT
    ///@param _tokenId the identifier of the NFT to query
    ///@return aavegotchiInfo_ a struct containing all details about
    function getCompany(uint256 _tokenId) external view returns (CompanyInfo memory companyInfo_) {
        companyInfo_ = LibCompany.getCompany(_tokenId);
    }

}