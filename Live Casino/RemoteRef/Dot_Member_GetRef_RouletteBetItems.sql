 USE [bodb_Odds]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_GetRef_RouletteBetItems]    Script Date: 09/06/2012 23:00:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Dot_Member_GetRef_RouletteBetItems]

AS
-- 2012/09/03@Stanley(Odds): Live Roulette Ref cache
/*
Created: Stanley.Wamg 
Date: 2012/09/03
Task: Live Roulette cache
*/
BEGIN
	select RefId, ResourceId, 
		Resource_en, Resource_ch, Resource_cs, Resource_jp, 
		Resource_it, Resource_th, Resource_ko, Resource_es, Resource_el
	from dbo.RefResource 
	where RefId = 'Roulette'
	order by ResourceId
END


