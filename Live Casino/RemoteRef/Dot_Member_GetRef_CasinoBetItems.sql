 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Dot_Member_GetRef_CasinoBetItems]

AS
/*
Created: Austin Su
Task : Live Casino Baccarat Bettype Name
DB: BODB_Odds
User: Dot_Member
*/
BEGIN
	select RefId, ResourceId, 
		Resource_en, Resource_ch, Resource_cs, Resource_jp, 
		Resource_it, Resource_th, Resource_ko, Resource_es, Resource_el
	from dbo.RefResource 
	where RefId = 'Baccarat'
	order by ResourceId
END

